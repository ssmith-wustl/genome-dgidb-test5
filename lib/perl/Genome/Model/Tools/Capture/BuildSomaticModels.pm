
package Genome::Model::Tools::Capture::BuildSomaticModels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# BuildSomaticModels - Compare tumor versus normal models to find somatic events
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

class Genome::Model::Tools::Capture::BuildSomaticModels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		processing_profile	=> { is => 'Text', doc => "Processing profile to use [Somatic-Capture-NoSV-Tier1only-Map40-Score40]", is_optional => 1 },
		data_dir	=> { is => 'Text', doc => "Data directory for somatic capture model subfolders [deprecated]" , is_optional => 1},
		sample_list	=> { is => 'Text', doc => "Text file of sample, normal-model-id, tumor-model-id" , is_optional => 0},
		subject_type	=> { is => 'Text', doc => "Subject type, e.g. sample_name, library_name [library_name]" , is_optional => 1},
		model_basename	=> { is => 'Text', doc => "String to use for naming models; sample will be appended" , is_optional => 0},
		report_only	=> { is => 'Text', doc => "Flag to skip actual execution" , is_optional => 1},
		use_bsub	=> { is => 'Text', doc => "If set to 1, will submit define command to short queue" , is_optional => 1},
		start_models	=> { is => 'Text', doc => "If set to 1, will start models after finding/creating them" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Define and build somatic-capture pipeline models for tumor-normal pairs"                 
}

sub help_synopsis {
    return <<EOS
Define and build somatic-capture pipeline models for tumor-normal pairs
EXAMPLE:	gt capture compare-models ...
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

	## Get required parameters ##
	my $processing_profile = "Somatic-Capture-NoSV-Tier1only-Map40-Score40";
	$processing_profile = $self->processing_profile if($self->processing_profile);

	my $sample_list = $self->sample_list;
	my $subject_type = "library_name";
	$subject_type = $self->subject_type if($self->subject_type);

	my $model_basename = $self->model_basename;

	my $data_dir = "./";
	$data_dir = $self->data_dir if($self->data_dir);

	if(!$self->report_only)
	{
		mkdir($data_dir) if (!(-d $data_dir));
	}

	## Reset statistics ##

	my $input = new FileHandle ($sample_list);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $tumor_sample_name, my $normal_model_id, my $tumor_model_id, my $normal_sample_name) = split(/\t/, $line);
		$stats{'num_pairs'}++;

		my @temp = split(/\-/, $tumor_sample_name);
		my $patient_id = join("-", $temp[0], $temp[1], $temp[2]);
		
		if($normal_sample_name)
		{
			$normal_sample_name =~ s/\$patient_id\-//;
		}

		my $model_name = $model_basename . "-" . $tumor_sample_name;
		$model_name .= "_" . $normal_sample_name if($normal_sample_name);

		my $model_id = get_model_id($model_name);

		print "$tumor_sample_name\t$model_name\n";

		## Build the somatic model ##
		if(!$model_id)
		{
			my $cmd = "genome model define somatic-capture --processing-profile-name \"$processing_profile\" --subject-name \"$tumor_sample_name\" --subject-type \"$subject_type\" --model-name \"$model_name\" --normal-model-id $normal_model_id --tumor-model-id $tumor_model_id";
			if($self->use_bsub)
			{
				system("bsub -q short $cmd") if(!$self->report_only);				
			}
			else
			{
				system("$cmd") if(!$self->report_only);
				$model_id = get_model_id($model_name) if(!$self->report_only);
			}
		}

		if($self->start_models && $model_id)
		{
			my $cmd = "genome model build start $model_id";
			print "RUN: $cmd\n";

			if(!$self->report_only)
			{
				system($cmd);
			}
		}

	}

	close($input);
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub get_model_id
{
	my $model_name = shift(@_);
	my $model_id = 0;

	my $model_output = `genome model list --filter=name=\'$model_name\' --show=id 2>/dev/null`;
	chomp($model_output);
	my @output_lines = split(/\n/, $model_output);
	
	foreach my $line (@output_lines)
	{
		$line =~ s/[^0-9]//g;
		if($line)
		{
			$model_id = $line;
		}
	}
	
	return($model_id);
}





1;

