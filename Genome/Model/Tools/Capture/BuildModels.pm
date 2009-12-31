
package Genome::Model::Tools::Capture::BuildModels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# BuildModels - Build Genome Models for Capture Datasets
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

class Genome::Model::Tools::Capture::BuildModels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		model_basename	=> { is => 'Text', doc => "Project string for model naming, e.g. \"TCGA-OV-6K-Capture-bwa\"", is_optional => 0 },
		processing_profile	=> { is => 'Text', doc => "Processing profile to use, e.g. \"bwa0.5.5 and samtools r510 and picard r107\"", is_optional => 1 },
		sample_list	=> { is => 'Text', doc => "Text file with sample names to include, one per line" , is_optional => 0},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Create and build genome models for capture datasets"                 
}

sub help_synopsis {
    return <<EOS
Create and build genome models for capture datasets
EXAMPLE:	gt capture build-models ...
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
	my $processing_profile = "bwa0.5.5 and samtools r510 and picard r107";
	$processing_profile = $self->processing_profile if($self->processing_profile);
	my $model_basename = $self->model_basename;
	my $sample_list = $self->sample_list;

	my $input = new FileHandle ($sample_list);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $sample_name) = split(/\t/, $line);
		
		## Determine model name ##
		
		my $model_name = $model_basename . $sample_name;

		## Attempt to get model id ##
		
		my $model_id = get_model_id($model_name);
		my $build_id = my $status = "";
		if($model_id)
		{
			## Model exists Get build status ##
			my $build_status = get_model_status($model_id);
			
			if($build_status)
			{
				($build_id, $status) = split(/\t/, $build_status);
			}
			else
			{
				warn "WARNING: Unable to get model status for $model_id\n";
			}
		}
		else
		{
			## Create new model ##
			system("genome model define reference-alignment --processing-profile-name=\"$processing_profile\" --subject-name=\"$sample_name\" --model-name=\"$model_name\" --auto-assign-inst-data --auto-build-alignments");
			$model_id = get_model_id($model_name);
			if($model_id)
			{
				system("genome model instrument-data assign --model-id $model_id --capture");
				system("bsub -q long genome model build start --model-identifier $model_id");				
			}
			else
			{
				warn "WARNING: Unable to build model $model_name\n";
			}

		}

		print "$sample_name\t$model_name\t$model_id\t$build_id\t$status\n";
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



#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub get_model_status
{
	my $model_id = shift(@_);
	my $status_xml = `genome model status --genome-model-id $model_id`;
	my $build_id = my $build_status = "";
	
	my @statusLines = split(/\n/, $status_xml);
	
	foreach my $line (@statusLines)
	{
		if($line =~ 'builds' && !$build_status)
		{
			$build_status = "Unbuilt";
		}
		
		if($line =~ 'build id')
		{
			my @lineContents = split(/\"/, $line);
			$build_id = $lineContents[1];
		}
		
		if($line =~ 'build_status')
		{
			my @lineContents = split(/[\<\>]/, $line);
			$build_status = $lineContents[2];
		}
	}
	
	return("$build_id\t$build_status");
}




1;

