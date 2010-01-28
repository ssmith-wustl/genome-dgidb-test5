
package Genome::Model::Tools::Capture::GetBamFiles;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GetBamFiles - Build Genome Models for Capture Datasets
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

class Genome::Model::Tools::Capture::GetBamFiles {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		model_basename	=> { is => 'Text', doc => "Project string for model naming, e.g. \"TCGA-OV-6K-Capture-bwa\"", is_optional => 0 },
		processing_profile	=> { is => 'Text', doc => "Processing profile to use, e.g. \"bwa0.5.5 and samtools r510 and picard r107\"", is_optional => 1 },
		sample_list	=> { is => 'Text', doc => "Text file with sample names to include, one per line" , is_optional => 0},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Obtain BAM files from completed models for capture datasets"                 
}

sub help_synopsis {
    return <<EOS
Obtain BAM files from completed models for capture datasets
EXAMPLE:	gt capture get-bam-files ...
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

	## Reset statistics ##
	$stats{'num_samples'} = 0;

#	print "Retrieving existing genome models...\n";
#	my %existing_models = get_genome_models($model_basename);

	my $input = new FileHandle ($sample_list);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $sample_name) = split(/\t/, $line);
		$stats{'num_samples'}++;

		## Determine model name ##
		
		my $model_name = $model_basename . $sample_name;

		## Reset model-related variables ##
		
		my $model_id = my $build_id = my $model_status = my $data_dir = my $bam_file = "";
		
		## Get the current model ##
		
		$model_id = get_model_id($model_name);
		
		if($model_id)
		{
			my %model_info = get_model_info($model_id);
			
			$model_status = $model_info{'status'};
			$data_dir = $model_info{'directory'};
			$build_id = $model_info{'latest-build-id'} if($model_info{'latest-build-id'});
			$bam_file = $model_info{'bam-file'} if($model_info{'bam-file'});

			print "$sample_name\t$model_id\t$model_status\t$build_id\t$bam_file\n";
		}

	}

	close($input);
	
	## Print summary report ##

	print $stats{'num_samples'} . " samples in file\n";

	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub get_genome_models
{
	my $model_basename = shift(@_);
	my %matching_models = ();
	$stats{'num_matching_models'} = 0;
	$stats{'num_completed_builds'} = 0;

	my $model_output = `genome model list --filter=name~\'$model_basename%\' --show=id,subject_name,last_complete_build_directory 2>/dev/null`;
	chomp($model_output);
	my @output_lines = split(/\n/, $model_output);
	
	foreach my $line (@output_lines)
	{
		my @lineContents = split(/\s+/, $line);
		if($lineContents[0])
		{
			my $model_id = $lineContents[0];
			$model_id =~ s/[^0-9]//g;
			if($model_id)
			{
				my $sample_name = $lineContents[1];
				my $build_dir = $lineContents[2];
				
				if($sample_name)
				{
					$stats{'num_matching_models'}++;
					
					$matching_models{$sample_name} = $model_id;
					
					if($build_dir && !($build_dir =~ 'NULL'))
					{
						## Get build ID ##
						my @tempArray = split(/\//, $build_dir);
						my $numElements = @tempArray;
						my $build_id = $tempArray[$numElements - 1];
						$build_id =~ s/[^0-9]//g;
						
						if($build_id)
						{
							$matching_models{$sample_name} = "$model_id\t$build_id\tCompleted\t$build_dir";
							$stats{'num_with_builds_completed'}++;
						}
					}

					
				}

				
			}
		}
	}
	
	print "$stats{'num_matching_models'} models matching \"$model_basename\"\n";

	return(%matching_models);
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
	my $status_xml = `genome model status --genome-model-id $model_id 2>/dev/null`;
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
		
		if($line =~ 'build-status')
		{
			my @lineContents = split(/[\<\>]/, $line);
			$build_status = $lineContents[2];
		}
	}
	
	return("$build_id\t$build_status");
}



#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub get_model_info
{
	my $model_id = shift(@_);
	my $status_xml = `genome model status --genome-model-id $model_id 2>/dev/null`;
	my $latest_build_id = my $model_status = my $data_dir = my $bam_file = "";
	
	my %model_info = ();
	
	my @statusLines = split(/\n/, $status_xml);
	
	foreach my $line (@statusLines)
	{
		if($line =~ 'data-directory')
		{
			my @lineContents = split(/\"/, $line);
			my $numContents = @lineContents;
			for(my $colCounter = 0; $colCounter < $numContents; $colCounter++)
			{
				if($lineContents[$colCounter] && $lineContents[$colCounter] =~ 'data-directory')
				{
					$data_dir = $lineContents[$colCounter + 1];
				}
			}
		}

		if($line =~ 'builds' && !$model_status)
		{
			$model_status = "Unbuilt";
		}
		
		if($line =~ 'build id')
		{
			my @lineContents = split(/\"/, $line);
			$latest_build_id = $lineContents[1];
		}
		
		if($line =~ 'build-status')
		{
			my @lineContents = split(/[\<\>]/, $line);
			$model_status = $lineContents[2];
		}
	}

	## If there was any build, try for the BAM file ##
	
	if($latest_build_id)
	{
		my $bam_list = `ls $data_dir/build$latest_build_id/alignments/*.bam 2>/dev/null`;
		chomp($bam_list) if($bam_list);
		
		## If latest build doesn't have one, go for any build ##
		
		if(!$bam_list)
		{
			$bam_list = `ls $data_dir/build$latest_build_id/alignments/*.bam 2>/dev/null`;
			chomp($bam_list) if($bam_list);
		}

		if($bam_list)
		{
			my @bam_lines = split(/\n/, $bam_list);
			foreach my $bam (@bam_lines)
			{
				if($bam && -e $bam)
				{
					$bam_file = $bam;
				}
			}
		}
	}
	
	$model_info{'status'} = $model_status;
	$model_info{'directory'} = $data_dir;
	$model_info{'bam-file'} = $bam_file if($bam_file);	
	$model_info{'latest-build-id'} = $latest_build_id if($latest_build_id);	

	return(%model_info);
}


1;

