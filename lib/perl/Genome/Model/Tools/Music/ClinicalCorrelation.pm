package Genome::Model::Tools::Music::ClinicalCorrelation;

use warnings;
use strict;
use Carp;
use Genome;
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
        doc => "Results of clinical-correlation tool. Will have suffix added for data type.",
    },
    maf_file => { 
        is => 'Text',
        doc => "List of mutations in MAF format",
        is_input => 1,
        file_format => 'maf',
    },
    numeric_clinical_data_file => {
        is => 'Text',
        doc => "Table of samples (y) vs. numeric clinical data category (x)",
        is_optional => 1,
    },
    categorical_clinical_data_file => {
        is => 'Text',
        doc => "Table of samples (y) vs. categorical clinical data category (x)",
        is_optional => 1,
    },
    genetic_data_type => {
        is => 'Text',
        doc => "Data in matrix file must be either \"gene\" or \"variant\" type data",
    },
    ],
    doc => "Identify correlations between mutations and phenotypic traits."
};

sub help_synopsis {
    return <<EOS
... music clinical-correlation --maf-file /path/myMAF.tsv --numeric-clinical-data-file /path/myNumericData.tsv --genetic-data-type 'gene' --output-file /path/output_file
... music clinical-correlation --maf-file /path/myMAF.tsv --numeric-clinical-data-file /path/myNumericData.tsv --categorical-clinical-data-file /path/myClassData.tsv --genetic-data-type 'gene' --output-file /path/output_file
EOS
}

sub help_detail {
    return <<EOS
This command identifies correlations between mutations recorded in a MAF and the particular phenotypic traits recorded for the same samples in separate clinical data files.

The clinical data files must be separated between numeric and categoric data and must follow these conventions:
- Headers are required
- Each file must include at least 1 sample_id column and 1 attribute column, with the format being [sample_id  clinical_data_attribute  clinical_data_attribute  ...]
- The sample ID must match the sample ID listed in the MAF under "Tumor_Sample_Barcode" for relating the mutations of this sample.

Note the importance of the headers: the header for each clinical_data_attribute will appear in the output file to denote relationships with the mutation data from the MAF.

Internally, the input data is fed into an R script which calculates a P-value representing the probability that the correlation seen between the mutations in each gene (or variant) and each phenotype trait are random. Lower P-values indicate lower randomness, or likely true correlations.

The results are saved to the output filename given with a suffix appended; ".numeric" will be appended for results derived from numeric clinical data, and ".categ" will be appended for results derived from categorical clinical data.
EOS
}

sub _doc_authors {
    return ('',
        'Nathan D. Dees, Ph.D.',
        'Qunyuan Zhang, Ph.D.',
        'William Schierding, M.S.',
    );
}

sub execute {

    #parse input arguments
    my $self = shift;
    my $output_file = $self->output_file;
    my $maf_file = $self->maf_file;
    my $genetic_data_type = $self->genetic_data_type;
    my %clinical_data;
    if ($self->numeric_clinical_data_file) {
        $clinical_data{'numeric'} = $self->numeric_clinical_data_file;
    }
    if ($self->categorical_clinical_data_file) {
        $clinical_data{'categ'} = $self->categorical_clinical_data_file;
    }

    #loop through clinical data files
    for my $datatype (keys %clinical_data) {

        my $test_method;
        my $full_output_filename;

        if ($datatype =~ /numeric/i) {
            $full_output_filename = $output_file . ".numeric";
            if ($genetic_data_type =~ /^gene$/i) {
                $test_method = "cor";
            }
            elsif ($genetic_data_type =~ /^variant$/i) {
                $test_method = "cor"; #cor instead of anova because we're assuming additive effect
            }
            else {
                $self->error_message("Please enter either \"gene\" or \"variant\" for the --genetic-data-type parameter.");
                return;
            }
        }

        if ($datatype =~ /categ/i) {
            #$test_method = "chisq";
            $full_output_filename = $output_file . ".categorical";
            $test_method = "fisher";
        }

        #read through clinical data file to see which samples are represented and create input matrix for R
        my %samples;
        my $matrix_file;
        my $samples = \%samples;
        my $clin_fh = new IO::File $clinical_data{$datatype},"r";
        unless ($clin_fh) {
            die "failed to open $clinical_data{$datatype} for reading: $!";
        }
        my $header = $clin_fh->getline;
        while (my $line = $clin_fh->getline) {
            my ($sample) = split /\t/,$line;
            $samples{$sample}++;
        }
        #create correlation matrix
        if ($genetic_data_type =~ /^gene$/i) {
            $matrix_file = create_sample_gene_matrix_gene($samples,$clinical_data{$datatype},$maf_file);
        }
        elsif ($genetic_data_type =~ /^variant$/i) {
            $matrix_file = create_sample_gene_matrix_variant($samples,$clinical_data{$datatype},$maf_file);
        }
        else {
            $self->error_message("Please enter either \"gene\" or \"variant\" for the --genetic-data-type parameter.");
            return;
        }

        my $R_cmd = "R --slave --args < " . __FILE__ . ".R " . $clinical_data{$datatype} . " $matrix_file $full_output_filename $test_method";
        print "R_cmd:\n$R_cmd\n";
        WIFEXITED(system $R_cmd) or croak "Couldn't run: $R_cmd ($?)";
    }

    return(1);
}

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
        unless (exists $samples->{$sample}) {
            warn "Sample Name: $sample from MAF file does not exist in Clinical Data File";
            next;
        }
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
        unless (exists $samples->{$sample}) {
            warn "Sample Name: $sample from MAF file does not exist in Clinical Data File";
            next;
        }
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

