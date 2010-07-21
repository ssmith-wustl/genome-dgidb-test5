
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

## Declare global statistics hash ##

my %stats = ();

class Genome::Model::Tools::Capture::BuildModels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		model_basename	=> { is => 'Text', doc => "Project string for model naming, e.g. \"TCGA-OV-6K-Capture-bwa\"", is_optional => 0 },
		processing_profile	=> { is => 'Text', doc => "Processing profile to use", is_optional => 1, default =>"bwa0.5.5 and samtools r544 and picard 1.17 and -q 5" },
		sample_list	=> { is => 'Text', doc => "Text file with sample names to include, one per line" , is_optional => 0},
		subject_type	=> { is => 'Text', doc => "Type of sample name in file (sample_name or library_name)" , is_optional => 1},
		report_only	=> { is => 'Text', doc => "Flag to skip actual genome model creation" , is_optional => 1},
		define_only	=> { is => 'Text', doc => "Flag to define models but not add data or build" , is_optional => 1},
		assign_only	=> { is => 'Text', doc => "Flag to define models, assign data, but not build" , is_optional => 1},
		restart_failed	=> { is => 'Text', doc => "Restarts failed builds" , is_optional => 1},
		restart_running	=> { is => 'Text', doc => "Forces restart of running builds" , is_optional => 1},
		restart_scheduled	=> { is => 'Text', doc => "Forces restart of scheduled builds" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Create and build genome models for capture datasets"                 
}

sub help_synopsis {
    return <<EOS
Create and build genome models for capture datasets
EXAMPLE:	gmt capture build-models ...
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
#	my $processing_profile = "bwa0.5.5 and samtools r544 and picard 1.17 and -q 5";
	my $processing_profile = $self->processing_profile;# if($self->processing_profile);
	my $model_basename = $self->model_basename;
	my $sample_list = $self->sample_list;
	my $subject_type = "sample_name";
	$subject_type = $self->subject_type if($self->subject_type);

	## Reset statistics ##
	$stats{'num_samples'} = $stats{'Created'} = $stats{'Started'} = $stats{'Completed'} = $stats{'Error'} = $stats{'Failed'} = $stats{'Running'} = $stats{'Scheduled'} = $stats{'Unbuilt'} = 0;

#	print "Retrieving existing genome models...\n";
#	my %existing_models = get_genome_models($model_basename);

	if(!($sample_list && -e $sample_list))
	{
		die "Sample list $sample_list not found!\n";
	}


	## Get existing models with this basename and processing profile ##

	print "Retrieving existing genome models...\n";
	my %existing_models = get_genome_models($model_basename, $processing_profile);


	my $input = new FileHandle ($sample_list);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $sample_name) = split(/\t/, $line);
		
		
		## Determine the model name ##
		
		my $model_name = $model_basename . "-" . $sample_name;
		my $model_id = 0;

		
		## Get existing model id, if there is one ##
		
		if($existing_models{$model_name})
		{
			($model_id) = split(/\,/, $existing_models{$model_name});
		}		
		else
		{
			$model_id = get_model_id($model_name);
			
			if(!$model_id)
			{
				## If we're not just reporting, create the model ##
				if($self->report_only)
				{
					print "Define model $model_name\n";
				}
				else
				{
					$model_id = define_model($model_name, $sample_name, $subject_type, $processing_profile);
				}
			}
		}

		## Proceed if we have a model id ##
		
		if($model_id)
		{
			print "$model_id\t$model_name\t$sample_name\n";

			## Get instrument data ##
			my $instrument_data = get_instrument_data($sample_name, $subject_type);
			if($instrument_data && !$self->define_only)
			{
				## Parse out the instrument data lines ##
				
				my @data_lines = split(/\n/, $instrument_data);
				foreach my $data_line (@data_lines)
				{
					#my @dataLineContents = split(/\,/, $data_line);
					(my $id, my $flow_cell_id, my $lane, my $filt_error_rate_avg, my $clusters, my $read_length, my $target_region_set_name) = split(/\,/, $data_line);
					print "$id\t$flow_cell_id\t$lane\t$filt_error_rate_avg\t$clusters\t$read_length\t$target_region_set_name\n";

					## Assign instrument data to model ##

					my $cmd = "genome model instrument-data assign --model-id $model_id --instrument-data-id $id";

					if(!$self->report_only)
					{
						system($cmd);
					}
				}
				

				## Build the model ##
				if(!$self->assign_only)
				{
					my $cmd = "genome model build start --model-id $model_id";
					print "RUN: $cmd\n";
					system($cmd);
				}
	
			}
		}
		else
		{
			print "Got no model id for $model_name\n";
		}
		
#		return(0);
		
	}
	close($input);

}



################################################################################################
# Execute - the main program logic
#
################################################################################################

sub get_instrument_data
{
	(my $sample_name, my $subject_type) = @_;
	
	my $instrument_data = `genome instrument-data list solexa --filter=$subject_type='$sample_name' --noheaders --style=csv --show=id,flow_cell_id,lane,filt_error_rate_avg,clusters,read_length,target_region_set_name`;
	if($instrument_data)
	{
#		my @instrument_data = split(/\n/, $instrument_data);
#		return(@instrument_data);
		return($instrument_data);
	}
	else
	{
		warn "No instrument data found with genome instrument-data list solexa --filter=$subject_type='$sample_name' --noheaders --style=csv --show=id,flow_cell_id,lane,filt_error_rate_avg,clusters,read_length,target_region_set_name\n";
		return();
	}
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub define_model
{
	(my $model_name, my $sample_name, my $subject_type, my $processing_profile) = @_;
	my $model_id = 0;

	my $cmd = "genome model define reference-alignment --processing-profile-name \"$processing_profile\" --model-name \"$model_name\" --subject-name=\"$sample_name\" --subject-type=\"$subject_type\"";
	print "RUN: $cmd\n";
	
	if(system($cmd))
	{
		return(0);
	}

	print "Model created without error; trying to get model id\n";
	$model_id = get_model_id($model_name);
	return($model_id);
}



















#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub get_genome_models
{
#	my $model_basename = shift(@_);
	(my $model_basename, my $pp_name) = @_;
	my %matching_models = ();
	$stats{'num_matching_models'} = 0;
	$stats{'num_completed_builds'} = 0;

	my $model_output = `genome model list --filter=processing_profile_name='$pp_name',name~\'$model_basename%\' --show=id,name,subject_name,last_succeeded_build_directory --noheaders --style csv 2>/dev/null`;
	chomp($model_output);
	my @output_lines = split(/\n/, $model_output);
	
	foreach my $line (@output_lines)
	{
		my @lineContents = split(/\,/, $line);
		if($lineContents[0])
		{
			my $model_id = $lineContents[0];
			$model_id =~ s/[^0-9]//g;
			if($model_id)
			{
				my $model_name = $lineContents[1];
				my $sample_name = $lineContents[2];
				my $build_dir = $lineContents[3];
				
				if($sample_name)
				{
					$stats{'num_matching_models'}++;
					
#					$matching_models{$sample_name} = $model_id;
					$matching_models{$model_name} = $model_id;
					
					my $build_status = "";
					
					if($build_dir && !($build_dir =~ 'NULL'))
					{
						## Get build ID ##
						my @tempArray = split(/\//, $build_dir);
						my $numElements = @tempArray;
						my $build_id = $tempArray[$numElements - 1];
						$build_id =~ s/[^0-9]//g;

						## Check for BAM file ##
						
						my $bam_list = `ls $build_dir/alignments/*.bam 2>/dev/null`;
						my @bam_lines = split(/\n/, $bam_list);
						
						foreach my $bam_line (@bam_lines)
						{
							if($bam_line && -e $bam_line)
							{
								$build_status = "Completed";
							}
						}
				
						if($build_id)
						{
							$matching_models{$model_name} = "$model_id\t$build_id\t$build_status\t$build_dir";
#							$matching_models{$sample_name} = "$model_id\t$build_id\t$build_status\t$build_dir";
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

	my $model_output = `genome model list --filter=name=\'$model_name\' --show=id --noheader 2>/dev/null`;
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

sub old
{
	my $self = shift;

	## Get required parameters ##
	my $processing_profile = "bwa0.5.5 and samtools r510 and picard r107";
	$processing_profile = $self->processing_profile if($self->processing_profile);
	my $model_basename = $self->model_basename;
	my $sample_list = $self->sample_list;
	my $subject_type = "sample_name";
	$subject_type = $self->subject_type if($self->subject_type);

	## Reset statistics ##
	$stats{'num_samples'} = $stats{'Created'} = $stats{'Started'} = $stats{'Completed'} = $stats{'Error'} = $stats{'Failed'} = $stats{'Running'} = $stats{'Scheduled'} = $stats{'Unbuilt'} = 0;

	print "Retrieving existing genome models...\n";
	my %existing_models = get_genome_models($model_basename);

	if(!($sample_list && -e $sample_list))
	{
		die "Sample list $sample_list not found!\n";
	}
	
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
		
		my $model_id = my $build_id = my $model_status = my $build_dir = "";
		
		if($existing_models{$sample_name})
		{
			my @modelContents = split(/\t/, $existing_models{$sample_name});
			$model_id = $modelContents[0];
			
			if($modelContents[1])
			{
				$build_id = $modelContents[1];
				$model_status = $modelContents[2];
				$build_dir = $modelContents[3];
			}
			else
			{
				## Incomplete build; get the model status ##

				my $build_status = get_model_status($model_id);
				
				if($build_status)
				{
					$stats{'num_with_builds'}++;
					($build_id, $model_status) = split(/\t/, $build_status);
					$stats{'num_with_builds_running'}++ if($model_status eq "Running");
					$stats{'num_with_builds_failed'}++ if($model_status eq "Failed");
					
					## IF not reporting, and restart desired, do it ##
					if(!$self->report_only)
					{
						if($model_status eq "Failed" && $self->restart_failed)
						{
							system("bsub -q long genome model build start --model-identifier $model_id --force 1");							
						}
						elsif($model_status eq "Running" && $self->restart_running)
						{
							system("bsub -q long genome model build start --model-identifier $model_id --force 1");							
						}
						elsif($model_status eq "Scheduled" && $self->restart_scheduled)
						{
							system("bsub -q long genome model build start --model-identifier $model_id --force 1");							
						}
					}
				}
				else
				{
					die "WARNING: Unable to get model status for $model_id\n";
				}
			}
		}
		
		## If no existing model, proceed to creation step ##
		
		if(!$model_id)
		{
			## Attempt to get model id ##
			
			$model_id = get_model_id($model_name);
			
			if($model_id)
			{
				## Model exists Get build status ##
				my $build_status = get_model_status($model_id);
				
				if($build_status)
				{
					($build_id, $model_status) = split(/\t/, $build_status);
				}
				else
				{
					die "WARNING: Unable to get model status for $model_id\n";
				}
			}
		}

		## If we have a model id, make note ##
		
		$stats{'num_with_existing_models'}++;


		## If there's still no model id, try to create the model ##

		if(!$model_id)
		{
			$model_status = "Created";

			## If we're not just reporting statuses ##
			if(!$self->report_only)
			{
				## Create the new model ##
				
#				system("genome model define reference-alignment --processing-profile-name=\"$processing_profile\" --subject-name=\"$sample_name\" --model-name=\"$model_name\" --auto-assign-inst-data --auto-build-alignments");
				$model_id = get_model_id($model_name);
				
				## If successful, add capture instrument data ##
				
				if($model_id)
				{
					system("genome model instrument-data assign --model-id $model_id --capture");
					
					## If possible, start the build ##
					system("bsub -q long genome model build start --model-identifier $model_id");
					$model_status = "Started";
				}
				else
				{
					warn "WARNING: Unable to build model $model_name\n";
					$model_status = "Error";
				}
			}
		}

		
		## Count the status ##
		
		$stats{$model_status}++ if($model_status);
		
		## Print the result ##1
		
		print "$sample_name\t$model_name\t$model_id\t$build_id\t$model_status\n";	

	}

	close($input);
	
	## Print summary report ##

#	print "$stats{'num_with_builds'} have existing builds\n";
#	print "$stats{'num_with_builds_completed'} builds Completed\n";
#	print "$stats{'num_with_builds_running'} builds Running\n";
#	print "$stats{'num_with_builds_failed'} builds Failed\n";
	
	print $stats{'num_samples'} . " samples in file\n";
	print $stats{'Created'} . " had new models created\n" if($stats{'Created'});
	print $stats{'Started'} . " had new models launched\n" if($stats{'Started'});
	print $stats{'Error'} . " failed to launch due to Error\n" if($stats{'Error'});
	print $stats{'num_with_existing_models'} . " had existing models\n";
	print $stats{'Unbuilt'} . " not yet built\n";
	print $stats{'Failed'} . " with build Failed\n";
	print $stats{'Scheduled'} . " with build Scheduled\n";
	print $stats{'Running'} . " with build Running\n";
	print $stats{'Completed'} . " with build Completed\n";

	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

