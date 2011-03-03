package Genome::Model::Tools::Music::ClinicalCorrelation;

use warnings;
use strict;
use Carp;
use Genome::Model::Tools::Music;
use IO::File;
use POSIX qw( WIFEXITED );

our $VERSION = $Genome::Model::Tools::Music::VERSION;

class Genome::Model::Tools::Music::ClinicalCorrelation {
    is => 'Genome::Model::Tools::Music::Base',                       
    has_input => [ 
        output_file => {
            is => 'Text',
            is_output => 1,
            file_format => 'text',
            doc => "Results of clinical-correlation tool",
        },
        maf_file => { 
            is => 'Text',
            doc => "List of mutations in MAF format",
            is_input => 1,
            file_format => 'maf',
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
        genetic_data_type => {
            is => 'Text',
            doc => "Data in matrix file must be either \"gene\" or \"variant\" type data",
        },
    ],
    doc => "identify correlations between mutations in genes and particular phenotypic traits"
};

sub help_synopsis {
    return <<EOS
genome music clinical-correlation --maf-file myMAF.tsv --clinical-data-file myData.tsv --clinical-data-type 'numeric' --genetic-data-type 'gene'
EOS
}

sub help_detail {
    return <<EOS
This command identifies correlations between mutations in genes and particular phenotypic traits.  

It tool accepts either a MAF file or a matrix of samples vs. genes, where the values in the matrix are the number of mutations in each sample per gene. If the matrix is provided, the MAF file is not needed. If only the MAF file is provided, the matrix will be created by the tool and saved to a file whose name will be the name of the clinical data file appended with ".correlation_matrix". This matrix is fed into an R tool which calculates a P-value representing the probability that the correlation seen between the mutations in each gene and each phenotype trait are random. Lower P-values indicate lower randomness, or true correlations.
EOS
}


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
    my $genetic_data_type = $self->genetic_data_type;

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
        unless ($clin_fh) {
            die "failed to open $clinical_data_file for reading: $!";
        }
        my $header = $clin_fh->getline;
        while (my $line = $clin_fh->getline) {
            my ($sample) = split /\t/,$line;
            $samples{$sample}++;
        }

        #create correlation matrix
        if ($genetic_data_type =~ /^gene$/i) {
                $matrix_file = create_sample_gene_matrix_gene($samples,$clinical_data_file,$maf_file);
        }
        elsif ($genetic_data_type =~ /^variant$/i) {
                $matrix_file = create_sample_gene_matrix_variant($samples,$clinical_data_file,$maf_file);
        }
        else {
                $self->error_message("Please enter either \"gene\" or \"variant\" for the --genetic-data-type parameter.");
                return;
        }

    }

    my $R_cmd = "R --slave --args < " . __FILE__ . ".R $clinical_data_file $matrix_file $output_file $test_method";
    WIFEXITED(system $R_cmd) or croak "Couldn't run: $R_cmd ($?)";

    return(1);
}

################################################################################

=head2	create_sample_gene_matrix_gene

This subroutine takes a MAF and creates a matrix of samples vs. gene, where the values in the matrix are the number of mutations in each sample per gene.

=cut

################################################################################

sub create_sample_gene_matrix_gene {

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
    #my $matrix_file = $clinical_data_file . ".correlation_matrix";
    my $matrix_file = Genome::Sys->create_temp_file_path();
    my $matrix_fh = new IO::File $matrix_file,"w";
    unless ($matrix_fh) {
        die "Failed to create matrix file $matrix_file!: $!";
    }
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

################################################################################

=head2	create_sample_gene_matrix_variant

This subroutine takes a MAF and creates a matrix of samples vs. variants, where the values in the matrix are 0,1,2 representing reference versus variant frequency.

=cut

################################################################################

sub create_sample_gene_matrix_variant {

    my ($samples,$clinical_data_file,$maf_file) = @_;

    #create hash of mutations from the MAF file
    my %variants_hash;
    my %all_variants;

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
        my $sample = $fields[$maf_columns{'Tumor_Sample_Barcode'}];
        next unless exists $samples->{$sample};
        my $gene = $fields[$maf_columns{'Hugo_Symbol'}];
	my $chr = $fields[$maf_columns{'Chromosome'}];
	my $start = $fields[$maf_columns{'Start_position'}];
	my $stop = $fields[$maf_columns{'End_position'}];
	my $ref = $fields[$maf_columns{'Reference_Allele'}];
	my $var1 = $fields[$maf_columns{'Tumor_Seq_Allele1'}];
	my $var2 = $fields[$maf_columns{'Tumor_Seq_Allele2'}];

	my $var;
	my $variant_name;
	if ($ref eq $var1) {
		$var = $var2;
		$variant_name = $gene."_".$chr."_".$start."_".$stop."_".$ref."_".$var;
		$variants_hash{$sample}{$variant_name}++;
		$all_variants{$variant_name}++;
	}
	elsif ($ref eq $var2) {
		$var = $var1;
		$variant_name = $gene."_".$chr."_".$start."_".$stop."_".$ref."_".$var;
		$variants_hash{$sample}{$variant_name}++;
		$all_variants{$variant_name}++;
	}
	elsif ($ref ne $var1 && $ref ne $var2) {
		$var = $var1;
		$variant_name = $gene."_".$chr."_".$start."_".$stop."_".$ref."_".$var;
		$variants_hash{$sample}{$variant_name}++;
		$all_variants{$variant_name}++;
		$var = $var2;
		$variant_name = $gene."_".$chr."_".$start."_".$stop."_".$ref."_".$var;
		$variants_hash{$sample}{$variant_name}++;
		$all_variants{$variant_name}++;
	}
	
    }
    $maf_fh->close;

    #sort variants for consistency
    my @variant_names = sort keys %all_variants;

    #write the input matrix for R code to a file #FIXME HARD CODE FILE NAME, OR INPUT OPTION
    my $matrix_file = $clinical_data_file . ".clinical_correlation_matrix";
    my $matrix_fh = new IO::File $matrix_file,"w";

    #print input matrix file header
    my $header = join("\t","Sample",@variant_names);
    $matrix_fh->print("$header\n");

    #print mutation relation input matrix
    for my $sample (sort keys %variants_hash) {
        $matrix_fh->print($sample);
        for my $variant (@variant_names) {
            if (exists $variants_hash{$sample}{$variant}) {
                $matrix_fh->print("\t$variants_hash{$sample}{$variant}");
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

