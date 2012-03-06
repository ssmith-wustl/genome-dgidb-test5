package Genome::Model::MutationalSignificance::Command::PlayMusic;

use strict;
use warnings;
use Genome;
use Workflow::Simple;

class Genome::Model::MutationalSignificance::Command::PlayMusic {
    is => ['Command::V2'],
    has_input => [
        processors => {
            is => 'Integer',
            default_value => 6,
            doc => 'TODO',
        },
        log_directory => {
            is => 'Text',
            doc => 'TODO',
        },
        bam_list => {
            is => 'Text',
            doc => 'TODO',
        },
        maf_file => {
            is => 'Text',
            doc => 'TODO',
        },
        roi_file => {
            is => 'Text',
            doc => 'TODO',
        },
        path_scan_output_file => {
            is => 'Text',
            doc => 'TODO',
        },
        smg_output_file => {
            is => 'Text',
            doc => 'TODO',
        },
        mutation_relation_output_file => {
            is => 'Text',
            doc => 'TODO',
        },
        clinical_correlation_output_file => {
            is => 'Text',
            doc => 'TODO',
        },
        cosmic_omim_output_file => {
            is => 'Text',
            doc => 'TODO',
        },
        pfam_output_file => {
            is => 'Text',
            doc => 'TODO',
        },
        output_dir => {
            is => 'Text',
            doc => 'TODO',
        },
        reference_build => {
            is => 'Path',
            doc => 'Put either "Build36" or "Build37"',
            is_output => 1,
            default => 'Build36',
        },
        reference_sequence => {
            is => 'Text',
            doc => 'Path to reference sequence in FASTA format'
        },
        pathway_file => {
            is => 'Text',
            doc => 'Tab-delimited file of pathway information',
        },
        gene_covg_dir => {
            is => 'Path',
            doc => 'TODO',
        },
    ],
    has_optional_input => [
        numeric_clinical_data_file => {
            is => 'Text',
            doc => 'Table of samples (y) vs. numeric clinical data category (x)',
        },
        categorical_clinical_data_file => {
            is => 'Text',
            doc => 'Table of samples (y) vs. categorical clinical data category (x)',
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
        matrix_file => {
            is => 'Text',
            doc => 'Define this argument to store a mutation matrix',
        },
        permutations => {
            is => 'Number',
            doc => 'Number of permutations used to determine P-values',
        },
        normal_min_depth => {
            is => 'Integer',
            doc => 'The minimum read depth to consider a Normal BAM base as covered',
        },
        tumor_min_depth => {
            is => 'Integer',
            doc => 'The minimum read depth to consider a Tumor BAM base as covered',
        },
        min_mapq => {
            is => 'Integer',
            doc => 'The minimum mapping quality of reads to consider towards read depth counts',
        },
        show_skipped => {
            is => 'Boolean',
            doc => 'Report each skipped mutation, not just how many',
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
        bmr_modifier_file => {
            is => 'Text',
            doc => 'Tab delimited list of values per gene that modify BMR before testing [gene_name               bmr_modifier]',
        },
        max_fdr => {
            is => 'Number',
            doc => 'The maximum allowed false discovery rate for a gene to be considered an SMG',
        },
        genetic_data_type => {
            is => 'Text',
            doc => 'Data in matrix file must be either "gene" or "variant" type data',
        },
        wu_annotation_headers => {
            is => 'Boolean',
            doc => 'Use this to default to wustl annotation format headers',
        },
        bmr_groups => {
            is => 'Integer',
            doc => 'Number of clusters of samples with comparable BMRs',
            default_value => 1,
        },
        separate_truncations => {
            is => 'Boolean',
            doc => 'Group truncational mutations as a separate category',
            default => 0,
        },
        merge_concurrent_muts => {
            is => 'Boolean',
            doc => 'Multiple mutations of a gene in the same sample are treated as 1',
            default => 0,
        },
        skip_non_coding => {
            is => 'Boolean',
            doc => 'Skip non-coding mutations from the provided MAF file',
            default_value => 1,
        },
        skip_silent => {
            is => 'Boolean',
            doc => 'Skip silent mutations from the provided MAF file',
            default_value => 1,
        },
        min_mut_genes_per_path => {
            is => 'Number',
            doc => 'Pathways with fewer mutated genes than this will be ignored',
        },
        processors => {
            is => 'Integer',
            doc => "Number of processors to use in SMG (requires 'foreach' and 'doMC' R packages)",
        },
        aa_range => {
            is => 'Text',
            doc => "Set how close a 'near' match is when searching for amino acid near hits",
            default => '2',
        },
        nuc_range => {
            is => 'Text',
            doc => "Set how close a 'near' match is when searching for nucleotide position near hits",
            default => '5',
        },
    ],


    has_output => [
        smg_result => {
            is => 'Text',
            doc => 'TODO',
        },
        pathscan_result => {
            is => 'Text',
            doc => 'TODO',
        },
        mr_result => {
            is => 'Text',
            doc => 'TODO',
        },
        pfam_result => {
            is => 'Text',
            doc => 'TODO',
        },
        proximity_result => {
            is => 'Text',
            doc => 'TODO',
        },
        cosmic_result => {
            is => 'Text',
            doc => 'TODO',
        },
        cct_result => {
            is => 'Text',
            doc => 'TODO',
        },
    ],
};

sub execute {
    my $self = shift;
    my $workflow = $self->_create_workflow;

    my $meta = $self->__meta__;
    my @all_params = $meta->properties(
        class_name => __PACKAGE__,
        is_input => 1,
    );
    my %properties;
    map {if (defined $self->{$_->property_name}){$properties{$_->property_name} = $self->{$_->property_name}} } @all_params;

    my @errors = $workflow->validate;
    unless ($workflow->is_valid) {
        die ("Errors encountered while validating workflow\n".join("\n",@errors));
    }

    my $output = Workflow::Simple::run_workflow_lsf(
        $workflow,
        %properties
    );

    unless ( defined $output ) {
        my @errors = @Workflow::Simple::ERROR;
        for (@errors) {
            print STDERR $_->error . "\n";
        }
        return;
    }

    return 1;
}

sub _create_workflow {
    my $self = shift;

    my $meta = $self->__meta__;
    my @input_params = $meta->properties(
        class_name => __PACKAGE__,
        is_input => 1,
    );
    my @input_properties;
    map {if (defined $self->{$_->property_name}){push @input_properties, $_->property_name}} @input_params;

    my @output_params = $meta->properties(
        class_name => __PACKAGE__,
        is_output => 1,
    );

    my @output_properties;
    map {push @output_properties, $_->property_name} @output_params;

    my $workflow = Workflow::Model->create(
        name => 'Play Music Inner Workflow',
        input_properties => \@input_properties,
        output_properties =>\@output_properties,
    );

    my $log_directory = $self->log_directory;
    $workflow->log_dir($log_directory);

    my $input_connector = $workflow->get_input_connector;
    my $output_connector = $workflow->get_output_connector;

    my @no_dependencies = ('Proximity', 'ClinicalCorrelation', 'CosmicOmim', 'Pfam');
    my @bmr = ('Bmr::CalcCovg', 'Bmr::CalcBmr');
    my @depend_on_bmr = ('PathScan', 'Smg');
    my @depend_on_smg = ('MutationRelation');
    for my $command_name (@no_dependencies, @bmr, @depend_on_bmr, @depend_on_smg) {
        $workflow = $self->_append_command_to_workflow($command_name, $workflow)
                    or return;
    }

    my $link = $workflow->add_link(
        left_operation => $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::Proximity'),                                                            $workflow),
        left_property => 'output_file',
        right_operation => $output_connector,
        right_property => 'proximity_result',
    );

    $link = $workflow->add_link(
        left_operation => $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::Pfam'), $workflow),
        left_property => 'output_file',
        right_operation => $output_connector,
        right_property => 'pfam_result',
    );

    $link = $workflow->add_link(
        left_operation => $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::MutationRelation'), $workflow),
        left_property => 'output_file',
        right_operation => $output_connector,
        right_property => 'mr_result',
    );

    $link = $workflow->add_link(
        left_operation => $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::PathScan'), $workflow),
        left_property => 'output_file',
        right_operation => $output_connector,
        right_property => 'pathscan_result',
    );

    $link = $workflow->add_link(
        left_operation => $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::Smg'), $workflow),
        left_property => 'output_file',
        right_operation => $output_connector,
        right_property => 'smg_result',
    );
    
    $link = $workflow->add_link(
        left_operation => $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::CosmicOmim'), $workflow),
        left_property => 'output_file',
        right_operation => $output_connector,
        right_property => 'cosmic_result',
    );

    $link = $workflow->add_link(
        left_operation => $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::ClinicalCorrelation'), $workflow),
        left_property => 'output_file',
        right_operation => $output_connector,
        right_property => 'cct_result',
    );

    my $op = $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::Bmr::CalcCovg'), $workflow);
    $op->operation_type->lsf_resource("-R \'select[mem>16000] rusage[mem=16000]\' -M 16000000");
    $op = $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::Bmr::CalcBmr'), $workflow);
    $op->operation_type->lsf_resource("-R \'select[mem>16000] rusage[mem=16000]\' -M 16000000");
    $op = $self->_get_operation_for_module_name($self->_get_operation_name_for_module('Genome::Model::Tools::Music::Smg'), $workflow);
    $op->operation_type->lsf_resource("-R \'select[mem>16000] rusage[mem=16000] span[hosts=1]\' -n ".$self->processors." -M 16000000");
    return $workflow;
}

sub _get_operation_name_for_module {
    my $self = shift;
    my $command_name = shift;
    return Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string($command_name));
}

sub _get_operation_for_module_name {
    my $self = shift;
    my $operation_name = shift;
    my $workflow = shift;

    foreach my $op ($workflow->operations) {
        if ($op->name eq $operation_name) {
            return $op;
        }
    }
    return;
}

sub _append_command_to_workflow {
    my $self = shift;
    my $command_name = shift;
    my $workflow = shift;
    my $lsf_project = shift;
    my $lsf_queue = shift;
    my $command_module = join('::', 'Genome::Model::Tools::Music', $command_name);
    my $command_meta = $command_module->__meta__;
    my $operation_name = $self->_get_operation_name_for_module($command_module);
    my $operation = $workflow->add_operation(
        name => $operation_name,
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
        )
    );
    $operation->operation_type->lsf_queue($lsf_queue);
    $operation->operation_type->lsf_project($lsf_project);
    my %links = $self->_play_music_dependencies;
    for my $property ($command_meta->_legacy_properties()) {
        next unless exists $property->{is_input} and $property->{is_input};
        my $property_name = $property->property_name;
        my $property_def = $links{$operation_name}{$property_name};
        if (!$property_def) {
            if (grep {/^$property_name$/} @{$workflow->operation_type->input_properties}) {
                $property_def = [$workflow->get_input_connector->name, $property_name];
            }
        }
        if(!$property->is_optional or defined $property_def) {
            if (!$property->is_optional and not defined $property_def) {
                die ("Non-optional property ".$property->property_name." is not provided\n");
            }
            my $from_op = $self->_get_operation_for_module_name($property_def->[0], $workflow);
            if (!$from_op) {
                print "looking for left operation ".$property_def->[0]."\n";
                print "left property ".$property_def->[1]."\n";
                print "right operation ".$operation->name."\n";
                print "right property ".$property_name."\n";
                die ("Didn't get a from operation for the link\n");
            }
            my $link = $workflow->add_link(
                left_operation => $from_op,
                left_property => $property_def->[1],
                right_operation => $operation,
                right_property => $property_name,
            );

        }
    }
    return $workflow;
}

sub _play_music_dependencies {
    #If the input property doesn't come from directly from the input connector with the same name, specify it here
    my $self = shift;
    my %operation_names = (
        bmr_calc_bmr_operation => 'Genome::Model::Tools::Music::Bmr::CalcBmr',
        bmr_calc_covg_operation => 'Genome::Model::Tools::Music::Bmr::CalcCovg',
        smg_operation => 'Genome::Model::Tools::Music::Smg',
        create_roi_operation => 'Genome::Model::MutationalSignificance::Command::CreateROI',
        path_scan_operation => 'Genome::Model::Tools::Music::PathScan',
        mutation_relation_operation => 'Genome::Model::Tools::Music::MutationRelation',
        proximity_operation => 'Genome::Model::Tools::Music::Proximity',
        clinical_correlation_operation => 'Genome::Model::Tools::Music::ClinicalCorrelation',
        cosmic_omim_operation => 'Genome::Model::Tools::Music::CosmicOmim',
        pfam_operation => 'Genome::Model::Tools::Music::Pfam',
    );
    my %names = map {$_ => $self->_get_operation_name_for_module($operation_names{$_})} keys %operation_names;
    my %links = (
        $names{path_scan_operation} => {
            bmr => [$names{bmr_calc_bmr_operation}, 'bmr_output'],
            output_file => ['input connector', 'path_scan_output_file'],
        },
        $names{smg_operation} => {
            gene_mr_file => [$names{bmr_calc_bmr_operation}, 'gene_mr_file'],
            output_file => ['input connector', 'smg_output_file'],
        },
        $names{mutation_relation_operation} => {
            output_file => ['input connector', 'mutation_relation_output_file'],
            gene_list => [$names{smg_operation}, 'output_file'],
        },
        $names{bmr_calc_bmr_operation} => {
            output_dir => [$names{bmr_calc_covg_operation}, 'output_dir'], #TODO: modify to be more specific. 
        },
        $names{clinical_correlation_operation} => {
            output_file => ['input connector', 'clinical_correlation_output_file'],
            #numeric_clinical_data_file => [$names{create_clinical_data_operation}, 'clinical_data_file'],
        },
        $names{cosmic_omim_operation} => {
            output_file => ['input connector', 'cosmic_omim_output_file'],
        },
        $names{pfam_operation} => {
            output_file => ['input connector', 'pfam_output_file'],
        },
    );
    return %links;
}

1;

