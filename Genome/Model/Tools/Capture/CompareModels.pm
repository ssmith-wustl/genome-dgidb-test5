
package Genome::Model::Tools::Capture::CompareModels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# CompareModels - Compare tumor versus normal models to find somatic events
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

class Genome::Model::Tools::Capture::CompareModels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		model_basename	=> { is => 'Text', doc => "Project string for model naming, e.g. \"TCGA-OV-6K-Capture-bwa\"", is_optional => 0 },
		processing_profile	=> { is => 'Text', doc => "Processing profile to use, e.g. \"bwa0.5.5 and samtools r510 and picard r107\"", is_optional => 1 },
		output_dir	=> { is => 'Text', doc => "Output directory for comparison files" , is_optional => 0},
		sample_list	=> { is => 'Text', doc => "Text file normal-tumor sample pairs to include, one pair per line" , is_optional => 0},
		report_only	=> { is => 'Text', doc => "Flag to skip actual execution" , is_optional => 1},
		skip_if_output_present => { is => 'Text', doc => "Do not attempt to run pipeline if output present" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Compare normal/tumor genome models for capture datasets"                 
}

sub help_synopsis {
    return <<EOS
Compare normal/tumor genome models for capture datasets
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
	my $processing_profile = "bwa0.5.5 and samtools r510 and picard r107";
	$processing_profile = $self->processing_profile if($self->processing_profile);
	my $model_basename = $self->model_basename;
	my $sample_list = $self->sample_list;
	my $output_dir = "./";
	$output_dir = $self->output_dir if($self->output_dir);

	if(!$self->report_only)
	{
		mkdir($output_dir . "/somatic_pipeline") if (!(-d "$output_dir/somatic_pipeline"));
	}

	## Reset statistics ##
	$stats{'num_with_builds_completed'} = $stats{'num_pipeline_output'} = 0;
	$stats{'num_pairs'} = $stats{'num_pairs_with_bams'} = $stats{'num_pairs_one_bam'} = $stats{'num_pairs_no_bams'} = 0;

	print "Retrieving existing genome models...\n";
	my %existing_models = get_genome_models($model_basename);

	my $input = new FileHandle ($sample_list);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $normal_sample, my $tumor_sample) = split(/\t/, $line);
		$stats{'num_pairs'}++;

		## Determine model name ##
		
		my $normal_model_name = $model_basename . $normal_sample;
		my $tumor_model_name = $model_basename . $tumor_sample;

		## Reset model-related variables ##
		
		my $normal_model_id = my $normal_build_id = my $normal_model_status = my $normal_build_dir = my $normal_bam_file = my $normal_snp_file = "";
		my $tumor_model_id = my $tumor_build_id = my $tumor_model_status = my $tumor_build_dir = my $tumor_bam_file = my $tumor_snp_file = "";

		## Get Normal and Tumor BAM files ##
	
		if($existing_models{$normal_sample})
		{
			$normal_bam_file = get_bam_file($existing_models{$normal_sample});
		}

		if($existing_models{$tumor_sample})
		{
			$tumor_bam_file = get_bam_file($existing_models{$tumor_sample});
		}	

		if($normal_bam_file && $tumor_bam_file)
		{
			$stats{'num_pairs_with_bams'}++;
			
			## Get the build IDs ##
			
			$tumor_build_id = get_build_id($existing_models{$tumor_sample});
			
			## Get the SNP files ##
			
			$normal_snp_file = get_snp_file($existing_models{$normal_sample});
			$tumor_snp_file = get_snp_file($existing_models{$tumor_sample});
			
			## Define a data directory ##
			my $data_dir = $output_dir . "/somatic_pipeline/" . $tumor_sample;			

			if($self->skip_if_output_present && -e "$data_dir/merged.somatic.snp.novel.tier1.gc")
			{
				$stats{'num_pipeline_output'}++;
			}
			elsif(!$self->report_only)
			{
				mkdir($data_dir) if(!(-d $data_dir));
				
				## Proceed if all components are available ##
				if($tumor_build_id && -d $data_dir && -e $normal_bam_file && -e $tumor_bam_file && -e $normal_snp_file && -e $tumor_snp_file)
				{
					## Launch the pipeline ##
					system("bsub -q long -R\"select[type==LINUX64 && model != Opteron250 && mem>4000] rusage[mem=4000]\" gmt somatic compare capture-bams --min-mapping-quality 40 --min-somatic-quality 40 --skip-sv 1 --only-tier-1 1 --skip-if-output-present 1 --normal-bam-file $normal_bam_file --tumor-bam-file $tumor_bam_file --normal-snp-file $normal_snp_file --tumor-snp-file $tumor_snp_file --build-id $tumor_build_id --data-directory $data_dir");

#					print "gmt somatic compare capture-bams --skip-sv 1 --only-tier-1 1 --skip-if-output-present 1 --normal-bam-file $normal_bam_file --tumor-bam-file $tumor_bam_file --normal-snp-file $normal_snp_file --tumor-snp-file $tumor_snp_file --build-id $tumor_build_id --data-directory $data_dir\n";
#					system("gmt somatic compare capture-bams --skip-sv 1 --only-tier-1 1 --skip-if-output-present 1 --normal-bam-file $normal_bam_file --tumor-bam-file $tumor_bam_file --normal-snp-file $normal_snp_file --tumor-snp-file $tumor_snp_file --build-id $tumor_build_id --data-directory $data_dir");
#					exit(0);
				}
			}
			else
			{
				print "$tumor_sample\n";
				print "Normal BAM: $normal_bam_file\n";
				print "Tumor BAM: $tumor_bam_file\n";
				print "Normal SNP: $normal_snp_file\n";
				print "Tumor SNP: $tumor_snp_file\n";
#				print "Build ID: $tumor_build_id\n";
#				print "Data Dir: $data_dir\n";
#				exit(0);
			}
		}
		elsif($normal_bam_file || $tumor_bam_file)
		{
			$stats{'num_pairs_one_bam'}++;
			if($self->report_only)
			{
				print "$tumor_sample\n";
				print "Normal BAM: $normal_bam_file\n";
				print "Tumor BAM: $tumor_bam_file\n";
				print "Normal SNP: $normal_snp_file\n";
				print "Tumor SNP: $tumor_snp_file\n";				
			}
		}
		else
		{
			$stats{'num_pairs_no_bams'}++;
			if($self->report_only)
			{
				print "$tumor_sample\n";
				print "Normal BAM: \n";
				print "Tumor BAM: \n";
				print "Normal SNP: \n";
				print "Tumor SNP: \n";				
			}
		}

	}

	close($input);
	
	print $stats{'num_with_builds_completed'} . " models with completed builds\n";
	print $stats{'num_pairs'} . " tumor-normal pairs in file\n";
	print $stats{'num_pairs_no_bams'} . " had no BAM files\n";
	print $stats{'num_pairs_one_bam'} . " had one BAM file\n";
	print $stats{'num_pairs_with_bams'} . " had both BAM files\n";
	print $stats{'num_pipeline_output'} . " have pipeline output already\n";
	
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

	my $model_output = `genome model list --filter=name~\'$model_basename%\' --show=id,subject_name,last_succeeded_build_directory 2>/dev/null`;
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
	my $build_dir = "";

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
					$build_dir = $lineContents[$colCounter + 1];
				}
			}
		}
		
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
	
	return("$model_id\t$build_id\t$build_status\t$build_dir");
}




#############################################################
# Get BAM file
#
#############################################################

sub get_bam_file
{
	my $existing_model = shift(@_);
	my @modelContents = split(/\t/, $existing_model);
	my $model_id = $modelContents[0];
	
	if($modelContents[1])
	{
		my $build_id = $modelContents[1];
		my $model_status = $modelContents[2];
		my $build_dir = $modelContents[3];

		my $model_dir = $build_dir;
		my $filter_string = "build" . $build_id;
		$model_dir =~ s/$build_dir//;

		if($build_dir && -d $build_dir)
		{
			## Search for the BAM file ##
			
			my $bam_file = `ls $build_dir/alignments/*.bam`;
			chomp($bam_file) if($bam_file);

			## If BAM file not found, try for one in another build dir ##
			
			if(!$bam_file)
			{
				$bam_file = `ls $model_dir/build*/alignments/*.bam | head -1`;
				chomp($bam_file) if($bam_file);							
			}

			return($bam_file) if($bam_file);
		}
	}

	return("");
}





#############################################################
# Get BAM file
#
#############################################################

sub get_build_id
{
	my $existing_model = shift(@_);
	my @modelContents = split(/\t/, $existing_model);
	my $model_id = $modelContents[0];
	
	if($modelContents[1])
	{
		my $build_id = $modelContents[1];
		my $model_status = $modelContents[2];
		my $build_dir = $modelContents[3];
		
		if(-d $build_dir)
		{
			return($build_id);
		}
	}

	return("");
}


#############################################################
# Get BAM file
#
#############################################################

sub get_snp_file
{
	my $existing_model = shift(@_);
	my @modelContents = split(/\t/, $existing_model);
	my $model_id = $modelContents[0];
	
	if($modelContents[1])
	{
		my $build_id = $modelContents[1];
		my $model_status = $modelContents[2];
		my $build_dir = $modelContents[3];

		if(-d $build_dir)
		{
			## Search for the BAM file ##
			
			my $snp_file = `ls $build_dir/*snp_related_metrics/filtered.indelpe.snps`;
			chomp($snp_file) if($snp_file);
			return($snp_file) if($snp_file);
		}
	}

	return("");
}



1;

