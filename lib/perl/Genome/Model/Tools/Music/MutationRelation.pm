package Genome::Model::Tools::Music::MutationRelation;

use warnings;
use strict;
use Carp;
use Genome;
use IO::File;
use POSIX qw( WIFEXITED );

our $VERSION = $Genome::Model::Tools::Music::VERSION;

class Genome::Model::Tools::Music::MutationRelation {
    is => 'Command::V2',                       
    has_input => [ 
        output_file => {
            is => 'Text',
            doc => "results of mutation-relation tool",
        },
        maf_file => { 
            is => 'Text',
            doc => "list of mutations in MAF format",
        },
        permutations => {
            is => 'Number',
            doc => "number of permutations used to determine P-values",
            is_optional => 1,
            default => 100,
        },
    ],
    doc => 'Identify relationships between mutated genes.'
};

sub help_synopsis {
    return <<EOS
 ... music mutation-relation --maf-file /path/myMAF.tsv --permutations 1000 --output-file /path/mutation_relation.csv
EOS
}

sub help_detail {
    return <<EOS
    This module parses a list of mutations in MAF format and attempts to determin relationships among mutated genes. The module employs a correlation test to see whether or not any two genes are mutated concurrently (positive correlation) or exclusively (negative correlation). Because of the possibility of largely varying numbers of mutations present in different genes, P-values are calculated using restricted permutations that take into account the distribution of mutation counts among the samples. In the output file, 'pand' is the P-value for concurrent mutation events, and 'pexc' is the P-value for exclusive mutation events.
EOS
}

sub _doc_authors {
    return ('',
        'Nathan D. Dees, Ph.D.',
        'Qunyuan Zhang, Ph.D.',
    );
}

sub execute {

    #parse input arguments
    my $self = shift;
    my $output_file = $self->output_file;
    my $permutations = $self->permutations;
    my $maf_file = $self->maf_file;

    #create sample-gene matrix
    my $matrix_file = create_sample_gene_matrix($maf_file);

    #perform mutation-relation test using R
    my $R_cmd = "R --slave --args < " . __FILE__ . ".R $matrix_file $permutations $output_file";
    print "$R_cmd\n";
    WIFEXITED(system $R_cmd) or croak "Couldn't run: $R_cmd ($?)";

    return(1);
}

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
    my $matrix_file = Genome::Sys->create_temp_file_path();
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

1;

