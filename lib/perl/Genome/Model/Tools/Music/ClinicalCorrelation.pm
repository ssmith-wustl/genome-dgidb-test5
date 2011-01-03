package Genome::Model::Tools::Music::ClinicalCorrelation;

use warnings;
use strict;
use Carp;
use Genome::Model::Tools::Music;
use IO::File;
use POSIX qw( WIFEXITED );

our $VERSION = $Genome::Model::Tools::Music::VERSION;

=head1 NAME

Genome::Music::ClinicalCorrelation - identification of relevant clinical phenotypes

=head1 VERSION

Version 1.01

=cut

#our $VERSION = '1.01';

class Genome::Model::Tools::Music::ClinicalCorrelation {
    is => 'Command',                       
    has => [ 
    output_file => {
        is => 'Text',
        doc => "Results of clinical-correlation tool",
    },
    maf_file => { 
        is => 'Text',
        doc => "List of mutations in MAF format",
        is_optional => 1,
    },
    matrix_file => {
        is => 'Text',
        doc => "Matrix of samples (y) vs. mutations (x)",
        is_optional => 1,
    },
    clinical_data_file => {
        is => 'Text',
        doc => "Table of samples (y) vs. clinical data category (x)",
    },
    clinical_data_type => {
        is => 'Text',
        doc => "Data must be either \"numeric\" or \"class\" type data",
    },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Identify correlations between mutations in genes and particular phenotypic traits"
}

sub help_synopsis {
    return <<EOS
This command identifies correlations between mutations in genes and particular phenotypic traits
EXAMPLE:	gmt music clinical-correlation --maf-file myMAF.tsv --clinical-data-file myData.tsv --clinical-data-type 'numeric'
EOS
}

sub help_detail {
    return <<EOS
This tool accepts either a MAF file or a matrix of samples vs. genes, where the values in the matrix are the number of mutations in each sample per gene. If the matrix is provided, the MAF file is not needed. If only the MAF file is provided, the matrix will be created by the tool and saved to a file whose name will be the name of the clinical data file appended with ".correlation_matrix". This matrix is fed into an R tool which calculates a P-value representing the probability that the correlation seen between the mutations in each gene and each phenotype trait are random. Lower P-values indicate lower randomness, or true correlations.
EOS
}


=head1 SYNOPSIS

Identifies significant phenotypic traits


=head1 USAGE

      music.pl clinical-corellation OPTIONS

      OPTIONS:

      --output-file		Output file for writing results
      --maf-file		List of mutations in MAF format
      --matrix-file		Path to samples-vs-mutated-genes matrix
      --clinical-data-file		Table of samples vs. clinical
      --clinical-data-type		Either 'numeric' or 'class' type of data


=head1 FUNCTIONS

=cut

################################################################################

=head2	execute

Initializes a new analysis

=cut

################################################################################

sub execute {

    #parse input arguments
    my $self = shift;
    my $output_file = $self->output_file;
    my $matrix_file = $self->matrix_file;
    my $maf_file = $self->maf_file;
    my $clinical_data_file = $self->clinical_data_file;
    my $clinical_data_type = $self->clinical_data_type;

    #check clinical_data_type parameter and choose test method accordingly
    my $test_method;
    if ($clinical_data_type =~ /^numeric$/i) {
        $test_method = "cor";
    }
    elsif ($clinical_data_type =~ /^class$/i) {
        #$test_method = "chisq";
        $test_method = "fisher";
    }
    else {
        $self->error_message("Please enter either \"numeric\" or \"class\" for the --clinical-data-type parameter.");
        return;
    }

    #create sample-gene matrix if necessary
    unless (defined $matrix_file) {
        unless (defined $maf_file) {
            $self->error_message("Please supply either a MAF file or a sample-gene-matrix file.");
            return;
        }

        #read through clinical data file to see which samples are represented
        my %samples;
        my $samples = \%samples;
        my $clin_fh = new IO::File $clinical_data_file,"r";
        my $header = $clin_fh->getline;
        while (my $line = $clin_fh->getline) {
            my ($sample) = split /\t/,$line;
            $samples{$sample}++;
        }

        #create correlation matrix
        $matrix_file = create_sample_gene_matrix($samples,$clinical_data_file,$maf_file);
    }

    my $R_cmd = "R --slave --args < clinical_correlation.R $clinical_data_file $matrix_file $output_file $test_method";
    WIFEXITED(system $R_cmd) or croak "Couldn't run: $R_cmd ($?)";

    return(1);
}


################################################################################

=head2	create_sample_gene_matrix

This subroutine takes a MAF and creates a matrix of samples vs. gene, where the values in the matrix are the number of mutations in each sample per gene.

=cut

################################################################################

sub create_sample_gene_matrix {

    my ($samples,$clinical_data_file,$maf_file) = @_;

    #create hash of mutations from the MAF file
    my %mutations;
    my %all_genes;
    my @all_genes;

    #open the MAF file
    my $maf_fh = new IO::File $maf_file,"r";

    #parse MAF header
    my $maf_header = $maf_fh->getline;
    while ($maf_header =~ /^#/) {
        $maf_header = $maf_fh->getline;
    }
    my %maf_columns;
    if ($maf_header =~ /Chromosome/) {
        #header exists. determine columns containing gene name and sample name.
        my @header_fields = split /\t/,$maf_header;
        for (my $col_counter = 0; $col_counter <= $#header_fields; $col_counter++) {
            $maf_columns{$header_fields[$col_counter]} = $col_counter;
        }
    }
    else {
        die "MAF does not seem to contain a header!\n";
    }

    #load mutations hash by parsing MAF
    while (my $line = $maf_fh->getline) {
        chomp $line;
        my @fields = split /\t/,$line;
        my $gene = $fields[$maf_columns{'Hugo_Symbol'}];
        my $sample = $fields[$maf_columns{'Tumor_Sample_Barcode'}];
        next unless exists $samples->{$sample};
        $all_genes{$gene}++;
        $mutations{$sample}{$gene}++;
    }
    $maf_fh->close;

    #sort @all_genes for consistency
    @all_genes = sort keys %all_genes;

    #write the input matrix for R code to a file #FIXME HARD CODE FILE NAME, OR INPUT OPTION
    my $matrix_file = $clinical_data_file . ".correlation_matrix";
    my $matrix_fh = new IO::File $matrix_file,"w";

    #print input matrix file header
    my $header = join("\t","Sample",@all_genes);
    $matrix_fh->print("$header\n");

    #print mutation relation input matrix
    for my $sample (sort keys %mutations) {
        $matrix_fh->print($sample);
        for my $gene (@all_genes) {
            if (exists $mutations{$sample}{$gene}) {
                $matrix_fh->print("\t$mutations{$sample}{$gene}");
            }
            else {
                $matrix_fh->print("\t0");
            }
        }
        $matrix_fh->print("\n");
    }

    return $matrix_file;
}

=head1 AUTHOR

The Genome Center at Washington University, C<< <software at genome.wustl.edu> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Genome::Music::ClinicalCorrelation

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license.

=cut

1; # End of Genome::Music::ClinicalCorrelation
