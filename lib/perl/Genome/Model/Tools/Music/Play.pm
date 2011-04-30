package Genome::Model::Tools::Music::Play;

use strict;
use warnings;

use Genome;

our $VERSION = $Genome::Model::Tools::Music::VERSION;

class Genome::Model::Tools::Music::Play {
    is => 'Command::V2',
    has_input => [
        bam_list => {
            is => 'Text',
            doc => 'Tab delimited list of BAM files [sample_name normal_bam tumor_bam]'
        },
        roi_file => {
            is => 'Text',
            doc => 'Tab delimited list of ROIs [chr start stop gene_name]'
        },
        reference_sequence => {
            is => 'Text',
            doc => 'Path to reference sequence in FASTA format'
        },
        output_dir => {
            is => 'Text',
            doc => 'Directory where output files and subdirectories will be written',
            is_output => 1,
        },
        maf_file => {
            is => 'Text',
            doc => 'List of mutations using TCGA MAF specifications v2.2'
        },

        clinical_data_file => {
            is => 'Text',
            doc => 'Table of samples (y) vs. clinical data category (x)',
        },
        clinical_data_type => {
            is => 'Text',
            doc => 'Data must be either "numeric" or "class" type data',
        },
        genetic_data_type => {
            is => 'Text',
            doc => 'Data in matrix file must be either "gene" or "variant" type data',
        },
        pathway_file => {
            is => 'Text',
            doc => 'Tab-delimited file of pathway information',
        },
    ],
    has_optional_input => [
        matrix_file => {
            is => 'Text',
            doc => 'Matrix of samples (y) vs. mutations (x)',
        },
        omimaa_dir => {
            is => 'Path',
            doc => 'omim amino acid mutation database folder',
        },
        cosmic_dir => {
            is => 'Path',
            doc => 'cosmic amino acid mutation database folder',
        },
        verbose => {
            is => 'Boolean',
            doc => 'turn on to display larger working output',
            default => 1,
        },
        permutations => {
            is => 'Number',
            doc => 'Number of permutations used to determine P-values',
        },
        normal_min_depth => {
            is => 'Integer',
            doc => "The minimum read depth to consider a Normal BAM base as covered",
        },
        tumor_min_depth => {
            is => 'Integer',
            doc => "The minimum read depth to consider a Tumor BAM base as covered",
        },
        min_mapq => {
            is => 'Integer',
            doc => "The minimum mapping quality of reads to consider towards read depth counts",
        },
        show_skipped => {
            is => 'Boolean',
            doc => "Report each skipped mutation, not just how many",
            default => 0,
        },
        genes_to_ignore => {
            is => 'Text',
            doc => 'Comma-delimited list of genes to ignore for background mutation rates',
        },
        bmr => {
            is => 'Number',
            doc => 'Background mutation rate in the targeted regions',
        },
        max_proximity => {
            is => 'Text',
            doc => 'Maximum AA distance between 2 mutations',
        },
    ],
    has_calculated_optional => [
        gene_covg_dir => {
            calculate_from => ['output_dir'],
            calculate => q{ $output_dir . '/gene_covgs'; },
        },
        gene_mr_file => {
            calculate_from => ['output_dir'],
            calculate => q{ $output_dir . '/gene_mrs'; },
        },
    ],
    has_constant => [
        cmd_list_file => { #If a workflow version of this tool is written, these parameters might be more useful
            is => 'Text',
            default_value => undef,
            is_optional => 1,
        },
        cmd_prefix => {
            is => 'Text',
            default_value => undef,
            is_optional => 1,
        },
    ],
    doc => 'Run the full suite of MuSiC tools sequentially.',
};

sub help_synopsis {
    return <<EOS
This tool takes as parameters all the information required of the individual tools.
EXAMPLE:    gmt music play --bam-list input/bams_to_analyze.txt --clinical-data-file input/numeric_clinical_data.csv --clinical-data-type numeric --maf-file input/myMAF.tsv --output-dir play_output_dir --pathway-file input/pathway_db --reference-sequence input/refseq/all_sequences.fa --roi-file input/all_coding_regions.bed --genetic-data-type gene
EOS
}

sub help_detail {
    return <<EOS
This tool runs all of the analysis tools on a set of data.
EOS
}

sub execute {
    my $self = shift;

    my @no_dependencies = ('Proximity', 'ClinicalCorrelation', 'CosmicOmim', 'MutationRelation', 'Pfam');
    my @bmr = ('Bmr::CalcCovg', 'Bmr::CalcBmr');
    my @depend_on_bmr = ('PathScan', 'Smg');
    for my $command_name (@no_dependencies, @bmr, @depend_on_bmr) {
        my $command = $self->_create_command($command_name)
            or return;

        $self->_run_command($command)
            or return;
    }

    return 1;
}

sub _create_command {
    my $self = shift;
    my $command_name = shift;

    my $command_module = join('::', 'Genome::Model::Tools::Music', $command_name);
    my $command_meta = $command_module->__meta__;

    my %params;
    for my $property ($command_meta->properties()) {
        next unless exists $property->{is_input} and $property->{is_input};
        my $property_name = $property->property_name;
        if($property_name eq 'output_file') {
            $params{$property_name} = $self->output_dir . '/' . $command_module->command_name_brief;
        } elsif(!$property->is_optional or defined $self->$property_name) {
            $params{$property_name} = $self->$property_name;
        }
    }

    my $command = $command_module->create(%params);
    unless($command) {
        $self->error_message('Failed to create command for ' . $command_name);
        return;
    }

    return $command;
}

sub _run_command {
    my $self = shift;
    my $command = shift;

    my $command_name = $command->command_name;
    $self->status_message('Running ' . $command_name . '...');
    my $rv = eval { $command->execute() };
    if($@) {
        my $error = $@;
        $self->error_message('Error running ' . $command_name . ': ' . $error);
        return;
    } elsif(not $rv) {
        $self->error_message('Command ' . $command_name . ' did not return a true value.');
        return;
    } else {
        $self->status_message('Completed ' . $command_name . '.');
        return 1;
    }
}

1;
