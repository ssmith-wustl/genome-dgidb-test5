
package Genome::Model::Tools::Capture::ExomeCopyNumber;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# ModelGroup - Build Genome Models for Capture Datasets
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	12/09/2009 by D.K.
#	MODIFIED:	12/09/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

## Declare global statistics hash ##

my %stats = ();


class Genome::Model::Tools::Capture::ExomeCopyNumber {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		group_id		=> { is => 'Text', doc => "ID of somatic-variation model group" , is_optional => 0},
		output_dir	=> { is => 'Text', doc => "An output directory to hold copy number results" , is_optional => 1},
		reference	=> 	{ is => 'Text', doc => "Reference to use for bam-readcounts-based filters; defaults to build 37" , is_optional => 1, default=> '/gscmnt/sata420/info/model_data/2857786885/build102671028/all_sequences.fa'},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Runs exome-based copy number on a model group of somatic-variation models"                 
}

sub help_synopsis {
    return <<EOS
This command runs exome-based copy number on a model group of somatic-variation models
EXAMPLE:	gmt capture exome-copy-number --group-id 3328 --output-dir varscan_copynumber
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;

	my $group_id = $self->group_id;
	my $output_dir = $self->output_dir;

	## Get the models in each model group ##

	my $model_group = Genome::ModelGroup->get($group_id);
	my @models = $model_group->models;
	my $debug_counter = 0;

	foreach my $model (@models)
	{
		$stats{'models_in_group'}++;
		
		my $model_id = $model->genome_model_id;
		my $model_name = $model->name;
		my $subject_name = $model->subject_name;
		$subject_name = "Model" . $model_id if(!$subject_name);

		## Get normal and tumor model ##
		
		my $normal_model = $model->normal_model;
		my $tumor_model = $model->tumor_model;

		## Get Model IDs ##
		
		my $normal_model_id = $normal_model->id;
		my $tumor_model_id = $tumor_model->id;

		## Get TCGA-Compliant Subject Names ##

		my $normal_subject_name = $normal_model->subject_name;
		my $tumor_subject_name = $tumor_model->subject_name;

		my ($sample_prefix) = split(/\-/, $normal_subject_name);
		$normal_subject_name =~ s/$sample_prefix/TCGA/;
		
		($sample_prefix) = split(/\-/, $tumor_subject_name);
		$tumor_subject_name =~ s/$sample_prefix/TCGA/;

		my @temp = split(/\-/, $tumor_subject_name);
		my $patient_id = join("-", $temp[0], $temp[1], $temp[2]);

		my $tumor_sample = $tumor_model->subject_name;
		my $normal_sample = $normal_model->subject_name;
		my $tumor_model_dir = $tumor_model->last_succeeded_build_directory;
		my $normal_model_dir = $normal_model->last_succeeded_build_directory;
		my $tumor_bam = `ls $tumor_model_dir/alignments/*.bam`; chomp($tumor_bam);
		my $normal_bam = `ls $normal_model_dir/alignments/*.bam`; chomp($normal_bam);
	
		my $output_dir = $self->varscan_copynumber . "/" . $tumor_sample . "-" . $normal_sample;
		mkdir($output_dir) if(!(-d $output_dir));
		my $cmd = "gmt varscan copy-number-parallel --output $output_dir/varScan.output --normal-bam $normal_bam --tumor-bam $tumor_bam";
		$cmd .= " --reference " . $self->reference if($self->reference);

		print "$cmd\n";

	}	
	
	return 1;
}



1;

