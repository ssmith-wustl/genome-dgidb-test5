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
    covariates => { is => 'Text', doc => "\"\+\"-delimited list \(example: PC1+PC2+PC3+PC4+PC5\) of the covariates to use from the phenotype file or \"NONE\" if none", default => 'NONE' },
    trv_types => { is => 'Text', doc => "colon-delimited list of which trv types to use as significant rare variants or \"ALL\" if no exclusions", default => 'NMD_TRANSCRIPT,NON_SYNONYMOUS_CODING:NMD_TRANSCRIPT,NON_SYNONYMOUS_CODING,SPLICE_SITE:NMD_TRANSCRIPT,STOP_LOST:NON_SYNONYMOUS_CODING:NON_SYNONYMOUS_CODING,SPLICE_SITE:STOP_GAINED:STOP_GAINED,SPLICE_SITE' },
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

    my $trv_types = $self->trv_types;
    my @trv_array = split(/:/, $trv_types);
    my $trv_types_to_use = "\"".join("\",\"", @trv_array)."\"";

    my $pheno_fh = new IO::File $phenotype_file,"r";
    my $pheno_header = $pheno_fh->getline;
    close($pheno_fh);
    my @pheno_headers = split(/\t/, $pheno_header);
    my $subject_column_header = shift(@pheno_headers);

    my $annot_fh = new IO::File $VEP_annotation_file,"r";
    my $annot_header = $annot_fh->getline;
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
    my ($tfh_R_option,$R_path_option) = Genome::Sys->create_temp_file;
    unless($tfh_R_option) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $R_path_option =~ s/\:/\\\:/g;

#    my $temp_path_output = Genome::Sys->create_temp_directory;
#    $temp_path_output =~ s/\:/\\\:/g;

    #-------------------------------------------------
    my $R_command_option = <<"_END_OF_R_";
### This is option file for burdentest.R ###

################### data files & key columns 
missing.data=c("NA",".","")

genotype.file="$mutation_file"
gfile.delimiter="\t"
gfile.vid="$project_name"   # variant id in genotype.file
gfile.sid="FIRST_ROW"              # subject id in genotype.file

phenotype.file="$phenotype_file"
pfile.delimiter="\t"
pfile.sid="$subject_column_header"    # subject id in phenotype.file

anno.file="$VEP_annotation_file"
afile.delimiter="\t"
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

    print $tfh_R_option "$R_command_option\n";

    #now create bsub commands
    #bsub -e err 'R --no-save < burdentest.R option_file_asms Q trigRES ABCA1 10000'

    my $bsub_base = "bsub -e err 'R --no-save < $base_R_commands $R_path_option";

    foreach my $phenotype (@pheno_headers) {
        foreach my $gene (@gene_names) {
            my $trait_type = 'Q'; #THIS SHOULD BE A HASH KEY THING
            print "$bsub_base $trait_type $phenotype $gene $permutations";
        }
    }


    return 1;
}


