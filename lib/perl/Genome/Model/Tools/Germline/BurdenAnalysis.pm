package Genome::Model::Tools::Germline::BurdenAnalysis;

use warnings;
use strict;
use Carp;
use Genome;
use IO::File;
use FileHandle;
use File::Basename;
use FileHandle;

my $dir_name = dirname(__FILE__);
my $R_script_file = $dir_name . "/burdenanalysis.R";

class Genome::Model::Tools::Germline::BurdenAnalysis {
  is => 'Genome::Model::Tools::Music::Base',
  has_input => [
    mutation_file => { is => 'Text', doc => "Mutation Matrix" },
    glm_clinical_data_file => { is => 'Text', doc => "Phenotype File" },
    VEP_annotation_file => { is => 'Text', doc => "List of mutations --VEP annotate then VEP parse" },
    project_name => { is => 'Text', doc => "The name of the project" },
    base_R_commands => { is => 'Text', doc => "The base R command library", default => "$R_script_file" },
    output_directory => { is => 'Text', doc => "Results of the Burden Analysis" },
    maf_cutoff => { is => 'Text', doc => "The cutoff to use to define which mutations are rare, 1 means no cutoff", default => '0.01' },
    permutations => { is => 'Text', doc => "The number of permutations to perform, typically from 100 to 10000, larger number gives more accurate p-value, but needs more time", default => '10000' },
    trv_types => { is => 'Text', doc => "colon-delimited list of which trv types to use as significant rare variants or \"ALL\" if no exclusions", default => 'NMD_TRANSCRIPT,NON_SYNONYMOUS_CODING:NMD_TRANSCRIPT,NON_SYNONYMOUS_CODING,SPLICE_SITE:NMD_TRANSCRIPT,STOP_LOST:NON_SYNONYMOUS_CODING:NON_SYNONYMOUS_CODING,SPLICE_SITE:STOP_GAINED:STOP_GAINED,SPLICE_SITE' },
    select_phenotypes => { is => 'Text', doc => "If specified, don't use all phenotypes from glm-model-file file, but instead only use these from a comma-delimited list -- this list's names must be an exact match to names specified in the glm-model-file", is_optional => 1},
    testing_mode => { is => 'Text', doc => "If specified, assumes you're just testing the code and will not bsub out the actual tests", default => '0'},
    sample_list_file => { is => 'Text', doc => "Limit Samples in the Variant Matrix to Samples Within this File - Sample_Id should be the first column of a tab-delimited file, all other columns are ignored", is_optional => 1,},
    missing_value_markers => { is => 'Text', doc => "Comma-delimited list of symbols that represent missing values such as \"NA\", \".\", or \"-\"", is_optional => 1, default => 'NA,.,-999'},
    glm_model_file => { is => 'Text', doc => 'File outlining the type of model, response variable, covariants, etc. for the GLM analysis. (See DESCRIPTION).', is_optional => 1,
    },
  ],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Run a burden analysis on germline (PhenotypeCorrelation) data"                 
}

sub help_synopsis {
    return <<EOS
Run a burden analysis on germline (PhenotypeCorrelation) data
EXAMPLE:	gmt germline burden-analysis --help
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
  return (
<<"EOS"

The clinical data file (glm-clinical-data-file) must follow these conventions:

=over 4

=item * Headers are required

=item * Each file must include at least 1 sample_id column and 1 attribute column, with the format being [sample_id  clinical_data_attribute_1 clinical_data_attribute_2 ...]

=item * The sample ID must match the sample ID listed in the VCF for relating the mutations of this sample. It uses an exact match, so all samples must have exactly the same nomenclature.

=back

The GLM analysis accepts a mixed numeric and categoric clinical data file, input using the parameter --glm-clinical-data-file. GLM clinical data must adhere to the formats described above for the correlation clinical data files. GLM also requires the user to input a --glm-model-file. This file requires specific headers and defines the analysis to be performed rather exactly. Here are the conventions required for this file:

=over 4

=item * Columns must be ordered as such:

=item [ analysis_type    clinical_data_trait_name    variant/gene_name   covariates  memo ]

=item * The 'analysis_type' column must contain either "Q", indicating a quantative trait, or "B", indicating a binary trait will be examined.

=item * The 'clinical_data_trait_name' is the name of a clinical data trait defined by being a header in the --glm-clinical-data-file.

=item * The 'variant/gene_name' can either be the name of one or more columns from the --glm-clinical-data-file, or the name of one or more mutated gene names from the MAF, separated by "|". If this column is left blank, or instead contains "NA", then each column from either the variant mutation matrix (--use-maf-in-glm) or alternatively the --glm-clinical-data-file is used consecutively as the variant column in independent analyses. 

=item * 'covariates' are the names of one or more columns from the --glm-clinical-data-file, separated by "+". For now, covariates must be the same for all phenotypes, but this flexibility will be added soon.

=item * 'memo' is any note deemed useful to the user. It will be printed in the output data file for reference.

=back

Example:

/gscuser/qzhang/gstat/burdentest/readme    (readme file)
/gscuser/qzhang/gstat/burdentest/option_file_asms    (option file, this sets up the whole program)
/gscuser/qzhang/gstat/burdentest/burdentest.R  (main program)
/gscuser/qzhang/gstat/burdentest/rarelib.R (library )

/gscuser/qzhang/gstat/burdentest/jobs (job examples)
/gscmnt/sata424/info/medseq/Freimer-Boehnke/burdentest20120205/results (results)

EOS
    );
}


###############

sub execute {                               # replace with real execution logic.
	my $self = shift;

    my $mutation_file = $self->mutation_file;
    my $phenotype_file = $self->glm_clinical_data_file;
    my $VEP_annotation_file = $self->VEP_annotation_file;
    my $base_R_commands = $self->base_R_commands;
    my $output_directory = $self->output_directory;

    my $project_name = $self->project_name;
    my $maf_cutoff = $self->maf_cutoff;
    my $permutations = $self->permutations;

    my @selected_phenotypes;
    if (defined($self->select_phenotypes)) {
        my @selected_phenotypes = split(/,/, $self->select_phenotypes);
    }

    my $glm_model_file = $self->glm_model_file;
    my $glm_model_fh = IO::File->new( $glm_model_file ) or die "Couldn't open $glm_model_file. $!\n";
    my $glm_header = $glm_model_fh->getline;
    chomp($glm_header);
    my %pheno_covar_type_hash;
    my %covariates_hash;
    while (my $line = $glm_model_fh->getline) {
        next if ($line =~ m/^#/);
        chomp($line);
        my ($analysis_type,$clinical_data_trait_name,$variant_name,$covariates,$memo) = split(/\t/,$line);
        if ($covariates eq 'NA') {
            $covariates = 'NONE';
        }
        if (defined($self->select_phenotypes)) {
            my $match = 0;
            foreach my $sel_pheno (@selected_phenotypes) {
                if ($sel_pheno eq $clinical_data_trait_name) {
                    $match = 1;
                }
            }
            unless ($match) {
                next;
            }
        }
        $pheno_covar_type_hash{$clinical_data_trait_name} = "$covariates\t$analysis_type";
        my (@covariates) = split(/\+/,$covariates);
        foreach my $covar (@covariates) {
            $covariates_hash{$covar}++;
        }
    }
    my $covariates = join("\+", keys(%covariates_hash));
    my $trv_types = $self->trv_types;
    my @trv_array = split(/:/, $trv_types);
    my $trv_types_to_use = "\"".join("\",\"", @trv_array)."\"";

    my $missing_value_markers = $self->missing_value_markers;
    my @missing_values = split(/,/,$missing_value_markers);
    my $R_missing_values = "\"\"";
    foreach my $marker (@missing_values) {
        $R_missing_values .= ",\"$marker\"";
    }

    #define subset of samples to use
    my %sample_name_hash;
    my $mutation_subset_file;
    if(defined($self->sample_list_file)) {
        my $sample_list_file = $self->sample_list_file;
        my $sample_list_inFh = Genome::Sys->open_file_for_reading($sample_list_file);
        while(my $sample_line = $sample_list_inFh->getline ) {
            chomp($sample_line);
            my ($sample_name, @line_stuff) = split(/\t/, $sample_line);
            $sample_name_hash{$sample_name}++;
        }
        close($sample_list_inFh);

        $mutation_subset_file = "$output_directory/Mutation_Matrix_Subset.txt";
        my $fh_mutmat_out = new IO::File $mutation_subset_file,"w";
        unless ($fh_mutmat_out) {
            die "Failed to create new mutation matrix $mutation_subset_file!: $!";
        }
        my $mutmat_inFh = new IO::File $mutation_file,"r";
        my $mutmat_header = $mutmat_inFh->getline;
        my ($name, @samples) = split(/\t/, $mutmat_header);
        my %sample_inclusion_hash;
        my $sample_count = 0;
        my @sample_names;
        foreach my $sname (@samples) {
            if (defined($sample_name_hash{$sname})) {
                $sample_inclusion_hash{$sample_count}++;
                push(@sample_names,$sname);
            }
            $sample_count++;
        }
        my $subset_samples = join("\t",@sample_names);
        print $fh_mutmat_out "$name\t$subset_samples\n";

        while(my $line = $mutmat_inFh->getline ) {
            chomp($line);
            my @line_stuff = split(/\t/, $line);
            my ($variant_name, @values) = split(/\t/, $line);
            my $sample_count = 0;
            my @included_values;
            foreach my $value_included (@values) {
                if (defined($sample_inclusion_hash{$sample_count})) {
                    push(@included_values,$value_included);
                }
                $sample_count++;
            }
            my $subset_values = join("\t",@included_values);
            print $fh_mutmat_out "$variant_name\t$subset_values\n";
        }
        close($mutmat_inFh);
        close($fh_mutmat_out);
    }
    else {
        $mutation_subset_file = $mutation_file;
    }

    #get phenos and determine if trait is binary or not
    my $pheno_fh = new IO::File $phenotype_file,"r";
    my $pheno_header = $pheno_fh->getline;
    chomp($pheno_header);
    my @pheno_headers = split(/\t/, $pheno_header);
    my $subject_column_header = shift(@pheno_headers);
    $subject_column_header =~ s/ /\./g;

=cut
    my @pheno_minus_covariates;
    if (defined($self->select_phenotypes)) {
        @pheno_minus_covariates = @selected_phenotypes;
    }
    else {
        my @covariate_options = split(/\+/, $covariates);
        foreach my $phead (@pheno_headers) {
            my $match = 0;
            foreach my $cov (@covariate_options) {
                if ($phead eq $cov) {
                    $match = 1;
                }
            }
            unless ($match) {
                push(@pheno_minus_covariates,$phead);
            }
        }
    }
=cut

    my $annot_fh = new IO::File $VEP_annotation_file,"r";
    my $annot_header = $annot_fh->getline;
    chomp($annot_header);
    my @annot_headers = split(/\t/, $annot_header);
    my $gene_name_in_header = 'Gene_Name';
    my $trv_name_in_header = 'Trv_Type';
    my $annot_count = 0;
    my %annot_header_hash;
    foreach $annot_header (@annot_headers) {
        if ($annot_header =~ m/$gene_name_in_header/i) {
            $gene_name_in_header = $annot_header;
            $annot_header_hash{$gene_name_in_header} = $annot_count;
        }
        elsif ($annot_header =~ m/$trv_name_in_header/i) {
            $trv_name_in_header = $annot_header;
            $annot_header_hash{$trv_name_in_header} = $annot_count;
        }
        $annot_count++;
    }
    my %gene_names_hash;
    while (my $line = $annot_fh->getline) {
        chomp($line);
        my @line_stuff = split(/\t/, $line);
        my $gene_name = $line_stuff[$annot_header_hash{$gene_name_in_header}];
        $gene_names_hash{$gene_name}++;
    }
    close($annot_fh);
    my @gene_names;
    foreach my $gene_name (sort keys %gene_names_hash) {
        push(@gene_names,$gene_name);
    }

    #make .R file
    my $R_option_file = "$output_directory/R_option_file.R";
    my $fh_R_option = new IO::File $R_option_file,"w";
    unless ($fh_R_option) {
        die "Failed to create R options file $R_option_file!: $!";
    }
    #-------------------------------------------------
    my $R_command_option = <<"_END_OF_R_";
### This is option file for burdentest.R ###

################### data files & key columns 
missing.data=c($R_missing_values)

genotype.file="$mutation_subset_file"
gfile.delimiter="\\t"
gfile.vid="$project_name"   # variant id in genotype.file
gfile.sid="FIRST_ROW"              # subject id in genotype.file

phenotype.file="$phenotype_file"
pfile.delimiter="\\t"
pfile.sid="$subject_column_header"    # subject id in phenotype.file

anno.file="$VEP_annotation_file"
afile.delimiter="\\t"
afile.vid="Variant_Name"  #variant id in anno.file
gene.col="$gene_name_in_header"
vtype.col="Trv_Type"
vtype.use=c($trv_types_to_use)

out.dir="$output_directory"
if (!file.exists(out.dir)==T) dir.create(out.dir)

covariates="$covariates"

########################### other options
maf.cutoff=$maf_cutoff

_END_OF_R_
    #-------------------------------------------------

    print $fh_R_option "$R_command_option\n";


    #now create bsub commands
    #bsub -e err 'R --no-save < burdentest.R option_file_asms Q trigRES ABCA1 10000'
    my $user = $ENV{USER};
    my $R_error_file = "$output_directory/R_error_file.err";
    my $bsub_base = "bsub -u $user\@genome.wustl.edu -e $R_error_file 'R --no-save \< $base_R_commands $R_option_file";
    foreach my $phenotype (sort keys %pheno_covar_type_hash) {
        my ($covariates,$analysis_data_type) = split(/\t/,$pheno_covar_type_hash{$phenotype});
        foreach my $gene (@gene_names) {
            if ($gene eq '-' || $gene eq 'NA' ) {
                next;
            }
            my $bsub_cmd = "$bsub_base $analysis_data_type $phenotype $gene $permutations\'";
            if ($self->testing_mode) {
                print "$bsub_cmd\n";
            }
            else {
                system($bsub_cmd);
            }
        }
    }

    return 1;
}


