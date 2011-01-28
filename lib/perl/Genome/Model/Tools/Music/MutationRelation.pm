package Genome::Model::Tools::Music::MutationRelation;

use warnings;
use strict;
use Carp;
use Genome;
use IO::File;
use POSIX qw( WIFEXITED );

=head1 NAME

Genome::Music::MutationRelation - identification of significantly mutated genes

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

class Genome::Model::Tools::Music::MutationRelation {
    is => 'Command',                       
    has => [ 
    output_file => {
        is => 'Text',
        doc => "Results of mutation-relation tool",
    },
    maf_file => { 
        is => 'Text',
        doc => "List of mutations in MAF format",
        is_optional => 1,
    },
    matrix_file => {
        is => 'Text',
        doc => "Matrix of samples (y) vs. genes with mutations (x)",
        is_optional => 1,
    },
    permutations => {
        is => 'Number',
        doc => "Number of permutations used to determine P-values",
        is_optional => 1,
        default => 100,
    },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Identify relationships between mutated genes"                 
}

sub help_synopsis {
    return <<EOS
This command identifies relationships between mutated genes
EXAMPLE:	gmt music mutation-relation --maf-file myMAF.tsv --permutations 1000 --output-file mut.rel.csv
EOS
}

sub help_detail { #FIXME
    return <<EOS
This tool accepts either a MAF file or a matrix of samples vs. gene, where the values in the matrix are a 1 if the gene has a mutations for a particular sample, and a 0 if there are no mutations in that gene for that sample. If the matrix is provided, the MAF file is not needed. If only the MAF file is provided, the matrix will be created by the tool and saved to a file whose name will be the name of the MAF file appended with ".mutation_relation_matrix". The matrix is fed to an R tool which 
EOS
}


=head1 SYNOPSIS

Identifies significantly mutated genes


=head1 USAGE

      music.pl mutation-relation OPTIONS

      OPTIONS:

      --output-file		Output file to contain results
      --maf-file		List of mutations in MAF format
      --matrix-file		Discrete matrix of sample vs genes with mutations
      --permutations		Number of permutations used to determine P-values


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
    my $permutations = $self->permutations;
    my $matrix_file = $self->matrix_file;
    my $maf_file = $self->maf_file;

    #create sample-gene matrix if necessary
    unless (defined $matrix_file) {
        unless (defined $maf_file) {
            $self->error_message("Please supply either a MAF file or a sample-gene-matrix file.");
            return;
        }
        $matrix_file = create_sample_gene_matrix($maf_file);
    }

    #perform mutation-relation test using R
    my $R_cmd = "R --slave --args < " . __FILE__ . ".R $matrix_file $permutations $output_file";
    print "$R_cmd\n"; #FIXME
    WIFEXITED(system $R_cmd) or croak "Couldn't run: $R_cmd ($?)";

    return(1);
}


################################################################################

=head2	create_sample_gene_matrix

This subroutine takes a MAF and creates a matrix of samples vs. gene, where the values in the matrix are the number of mutations in each sample per gene.

=cut

################################################################################

sub create_sample_gene_matrix {

    my ($maf_file) = @_;

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
        $all_genes{$gene}++;
        $mutations{$sample}{$gene}++;
    }
    $maf_fh->close;

    #sort @all_genes for consistency
    @all_genes = sort keys %all_genes;

    #write the input matrix for R code to a file #FIXME HARD CODE FILE NAME, OR INPUT OPTION
    my $matrix_file = $maf_file . ".mutation_relation_matrix";
    my $matrix_fh = new IO::File $matrix_file,"w";

    #print input matrix file header
    my $header = join("\t","Sample",@all_genes);
    $matrix_fh->print("$header\n");

    #print mutation relation input matrix
    for my $sample (sort keys %mutations) {
        $matrix_fh->print($sample);
        for my $gene (@all_genes) {
            if (exists $mutations{$sample}{$gene}) {
                $matrix_fh->print("\t1");
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

    perldoc Genome::Music::MutationRelation

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license.

=cut

1; # End of Genome::Music::MutationRelation
