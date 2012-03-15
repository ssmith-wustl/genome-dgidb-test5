package Genome::Model::Tools::Germline::BurdenAnalysis;

use warnings;
use strict;
use Carp;
use Genome;
use IO::File;
use POSIX qw( WIFEXITED );

class Genome::Model::Tools::Germline::BurdenAnalysis {
  is => 'Genome::Model::Tools::Music::Base',
  has_input => [
    mutation_file => { is => 'Text', doc => "Mutation Matrix" },
    phenotype_file => { is => 'Text', doc => "Phenotype File" },
    VEP_annotation_file => { is => 'Text', doc => "List of mutations --VEP annotate then VEP parse" },
    project_name => { is => 'Text', doc => "The name of the project" },
    base_R_commands => { is => 'Text', doc => "The base R command library", default => '/gscuser/qzhang/gstat/burdentest/burdentest.R' },
    output_directory => { is => 'Text', doc => "Results of the Burden Analysis" },
    maf_cutoff => { is => 'Text', doc => "The cutoff to use to define which mutations are rare, 1 means no cutoff", default => '0.01' },
    permutations => { is => 'Text', doc => "The number of permutations to perform, typically from 100 to 10000, larger number gives more accurate p-value, but needs more time", default => '10000' },
    covariates => { is => 'Text', doc => "\"\+\"-delimited list \(example: PC1+PC2+PC3+PC4+PC5\) of the covariates to use from the phenotype file or \"NONE\" or \"NA\" if none", default => 'NONE' },
    trv_types => { is => 'Text', doc => "colon-delimited list of which trv types to use as significant rare variants or \"ALL\" if no exclusions", default => 'NMD_TRANSCRIPT,NON_SYNONYMOUS_CODING:NMD_TRANSCRIPT,NON_SYNONYMOUS_CODING,SPLICE_SITE:NMD_TRANSCRIPT,STOP_LOST:NON_SYNONYMOUS_CODING:NON_SYNONYMOUS_CODING,SPLICE_SITE:STOP_GAINED:STOP_GAINED,SPLICE_SITE' },
    select_phenotypes => { is => 'Text', doc => "If specified, don't use all phenotypes from phenotype file, but instead only use these from a comma-delimited list"},
    testing_mode => { is => 'Text', doc => "If specified, assumes you're just testing the code and will not bsub out the actual tests", default => '0'},
    sample_list_file => { is => 'Text', doc => "Limit Samples in the Variant Matrix to Samples Within this File - Sample_Id should be the first column of a tab-delimited file, all other columns are ignored", is_optional => 1,},
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
    my $phenotype_file = $self->phenotype_file;
    my $VEP_annotation_file = $self->VEP_annotation_file;
    my $base_R_commands = $self->base_R_commands;
    my $output_directory = $self->output_directory;

    my $project_name = $self->project_name;
    my $maf_cutoff = $self->maf_cutoff;
    my $permutations = $self->permutations;

    my $covariates = $self->covariates;
    if ($covariates eq 'NA') {
        $covariates = 'NONE';
    }

    my $trv_types = $self->trv_types;
    my @trv_array = split(/:/, $trv_types);
    my $trv_types_to_use = "\"".join("\",\"", @trv_array)."\"";

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
    my %is_it_binary;
    while (my $line = $pheno_fh->getline) {
        chomp($line);
        my @line_stuff = split(/\t/, $line);
        if(defined($self->sample_list_file)) {
            my $sname = $line_stuff[0];
            unless (defined($sample_name_hash{$sname})) {
                next;
            }
        }
        my $counter = 0;
        foreach my $pheader (@pheno_headers) {
            my $phenovalue = $line_stuff[$counter];
            $is_it_binary{$pheader}{$phenovalue}++;
            $counter++;
        }
    }
    close($pheno_fh);

    my $subject_column_header = shift(@pheno_headers);
    my @pheno_minus_covariates;
    if (defined($self->select_phenotypes)) {
        my @selected_phenotypes = split(/,/, $self->select_phenotypes);
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
unless(defined($gene_name)) {
print "$line\n";
}
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
missing.data=c("NA",".","")

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
    my $bsub_base = "bsub -u $user\@genome.wustl.edu -e err 'R --no-save \< $base_R_commands $R_option_file";
    foreach my $phenotype (@pheno_minus_covariates) {
        my $analysis_data_type;
        if (defined($is_it_binary{$phenotype})) {
            my $binary_assessment = scalar(keys %{$is_it_binary{$phenotype}});
            if ($binary_assessment < 3) {
                $analysis_data_type = 'B';
            }
            else {
                $analysis_data_type = 'Q';
            }
        }
        else {
            warn "You screwed up your code here somehow: pheno $phenotype\n";
            $analysis_data_type = 'Q';
        }
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


