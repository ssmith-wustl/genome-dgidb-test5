
package Genome::Model::Tools::Capture::CheckSomaticModels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# CheckSomaticModels - Compare tumor versus normal models to find somatic events
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	12/09/2009 by D.K.
#	MODIFIED:	08/13/2010 by D.K.
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

class Genome::Model::Tools::Capture::CheckSomaticModels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		processing_profile	=> { is => 'Text', doc => "Processing profile to use [Somatic-Capture-NoSV-Tier1only-Map40-Score40]", is_optional => 1 },
		data_dir	=> { is => 'Text', doc => "Output directory for comparison files" , is_optional => 0},
		sample_list	=> { is => 'Text', doc => "Text file of sample, normal-model-id, tumor-model-id" , is_optional => 0},
		subject_type	=> { is => 'Text', doc => "Subject type, e.g. sample_name, library_name [library_name]" , is_optional => 1},
		model_basename	=> { is => 'Text', doc => "String to use for naming models; sample will be appended" , is_optional => 0},
		report_only	=> { is => 'Text', doc => "Flag to skip actual execution" , is_optional => 1},
		use_bsub	=> { is => 'Text', doc => "If set to 1, will submit define command to short queue" , is_optional => 1},
		build_mafs	=> { is => 'Text', doc => "If set to 1, will build MAF files for completed models" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Check the status of somatic models"                 
}

sub help_synopsis {
    return <<EOS
Check the status of somatic models
EXAMPLE:	gt capture check-somatic-models ...
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


	## Print the header ##
	
	print "TUMOR_SAMPLE_NAME\tMODEL_ID\tBUILD_ID\tSTATUS\tVSCAN\tSNIPER\tMERGED\tFILTER\tNOVEL\tTIER1\tINDELS\tTIER1\n";


	my $input = new FileHandle ($sample_list);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $sample_name, my $normal_sample_name) = split(/\t/, $line);
		$stats{'num_pairs'}++;

		my $model_name = $model_basename . "-" . $sample_name;
		my $model_id = get_model_id($model_name);
		
		if(!$model_id)
		{
			print "Didn't find $model_name\n";
			$model_name = substr($model_name, 0, length($model_name) - 2);
			$model_id = get_model_id($model_name);
			print "Didn't find $model_name\n";
		}
		
		my $model_status = "Unknown";

		## Build the somatic model ##
		if(!$model_id)
		{
			print "$sample_name\tNo Model Named $model_name\n";
		}
		else
		{
			my $model_dir = $data_dir . "/" . $model_name;
			my @build_ids = get_build_ids($model_dir);
			
			## Iterate through builds ##
			
			my $buildCounter = 0;
			foreach my $build_id (@build_ids)
			{
				$buildCounter++;
				
				my $build_dir = "$model_dir/build$build_id";
				
				## Determine paths to key files ##
				
				my $server_status_file = "$build_dir/server_location.txt";
				my $merged_file = "$build_dir/merged.somatic.snp";
				my $filter_file = "$build_dir/merged.somatic.snp.filter";
				my $novel_file = "$build_dir/merged.somatic.snp.filter.novel";
				my $tier1_file = "$build_dir/merged.somatic.snp.filter.novel.tier1";

				my $indel_file = "$build_dir/merged.somatic.indel";
				my $indel_tier1_file = "$build_dir/merged.somatic.indel.filter.tier1";

				my $gatk_indel_file = "$build_dir/gatk.output.indel.formatted.Somatic";
				my $gatk_indel_tier1_file = "$build_dir/gatk.output.indel.formatted.Somatic.tier1";

				my $varscan_file = "$build_dir/varScan.output.snp";
				my $varscan_somatic_file = "$build_dir/varScan.output.snp.formatted.Somatic.hc";

				my $sniper_somatic_file = "$build_dir/somaticSniper.output.snp.filter.hc.somatic";
				my $sniper_hc_file = "$build_dir/somaticSniper.output.snp.filter.hc";
				my $sniper_file = "$build_dir/somaticSniper.output.snp.filter";


				## Determine Varscan status ##

				my $varscan_status = "Unknown";
				$varscan_status = "Done" if(-e $varscan_somatic_file);
				if(-e $varscan_somatic_file)
				{
					$varscan_status = `cat $varscan_somatic_file | wc -l`;
					chomp($varscan_status);
				}
				elsif(-e $varscan_file)
				{
					$varscan_status = `tail -2 $varscan_file | head -1 | cut -f 1`;
					chomp($varscan_status);
					$varscan_status = "chr" . $varscan_status;
				}
				else
				{
					$varscan_status = "--";
				}

				## Get Sniper Status ##
				my $sniper_status = "Unknown";
				if(-e $sniper_somatic_file)
				{
					$sniper_status = `cat $sniper_somatic_file | wc -l`;
					chomp($sniper_status);
				}
				elsif(-e $sniper_hc_file)
				{
					$sniper_status = "HC";
				}
				elsif(-e $sniper_file)
				{
					$sniper_status = "Filt";
				}

				## Determine build status ##
				
				my $build_status = "New";
				my %build_stats = ();
				
				
				
				## Count Indels ##
				
				if(-e $indel_file)
				{
					$build_stats{'indels_merged'} = `cat $indel_file | wc -l`;
					chomp($build_stats{'indels_merged'});
					
					if(-e $indel_tier1_file)
					{
						$build_stats{'indels_tier1'} = `cat $indel_tier1_file | wc -l`;
						chomp($build_stats{'indels_tier1'});
						$stats{'indels_completed'}++;
					}
				}
				
				if(-e $gatk_indel_file)
				{
					$build_stats{'gatk_indels'} = `cat $gatk_indel_file | wc -l`;
					chomp($build_stats{'gatk_indels'});
					
					if(-e $gatk_indel_tier1_file)
					{
						$build_stats{'gatk_indels_tier1'} = `cat $gatk_indel_tier1_file | wc -l`;
						chomp($build_stats{'gatk_indels_tier1'});
					}
				}
				
				if(-e $merged_file)
				{
					$build_status = "Merged";
					
					## Count merged SNPs ##
					$build_stats{'snps_merged'} = `cat $merged_file | wc -l`;
					chomp($build_stats{'snps_merged'});
					
					if(-e $filter_file)
					{						
						$build_status = "Filtered";
				
						## Count Filtered SNPs ##
						$build_stats{'snps_filtered'} = `cat $filter_file | wc -l`;
						chomp($build_stats{'snps_filtered'});

						if(-e $novel_file)
						{
							$build_status = "Novel";
							
							## Count Novel SNPs ##
							$build_stats{'snps_novel'} = `cat $novel_file | wc -l`;
							chomp($build_stats{'snps_novel'});
							
							if(-e $tier1_file)
							{
								$stats{'snvs_completed'}++;
								
								if(-e $server_status_file)
								{
									$build_status = "Running";
								}
								else
								{
									$build_status = "Done";
								}
									
								
								## Count Tier 1 SNPs ##
								$build_stats{'snps_tier1'} = `cat $tier1_file | wc -l`;
								chomp($build_stats{'snps_tier1'});
							}
						}
					}
					
				}
				else
				{
					## No merged file exists; so check for Varscan/Sniper files ##

				}
				
				
				## If we build the MAFs ##
				if($self->build_mafs && -e $tier1_file)# && -e $indel_tier1_file)
				{
					## Build the MAF file ##
					
					my $cmd = "gmt capture build-maf-file --data-dir $build_dir --normal-sample $normal_sample_name --tumor-sample $sample_name --output-file $build_dir/tcga-maf.tsv";
					system("bsub -q long $cmd");
				}
				
				$build_stats{'snps_merged'} = "-" if(!$build_stats{'snps_merged'});
				$build_stats{'snps_filtered'} = "-" if(!$build_stats{'snps_filtered'});
				$build_stats{'snps_novel'} = "-" if(!$build_stats{'snps_novel'});
				$build_stats{'snps_tier1'} = "-" if(!$build_stats{'snps_tier1'});
				$build_stats{'indels_merged'} = "-" if(!$build_stats{'indels_merged'});
				$build_stats{'indels_tier1'} = "-" if(!$build_stats{'indels_tier1'});
				$build_stats{'gatk_indels'} = "-" if(!$build_stats{'gatk_indels'});
				$build_stats{'gatk_indels_tier1'} = "-" if(!$build_stats{'gatk_indels_tier1'});
				
				## Update model status for this build ##
				$model_status = "$build_id\t$build_status\t$varscan_status\t$sniper_status";
				$model_status .= "\t" . $build_stats{'snps_merged'};
				$model_status .= "\t" . $build_stats{'snps_filtered'};
				$model_status .= "\t" . $build_stats{'snps_novel'};
				$model_status .= "\t" . $build_stats{'snps_tier1'};
				$model_status .= "\t" . $build_stats{'indels_merged'};
				$model_status .= "\t" . $build_stats{'indels_tier1'};
				$model_status .= "\t" . $build_stats{'gatk_indels'};
				$model_status .= "\t" . $build_stats{'gatk_indels_tier1'};
				
				print "$sample_name\t$model_id\t$model_status\n";#\t$build_dir\n";
				
				$stats{$build_status}++;
			}

			## End of build iteration
			
			
		}

	}

	close($input);


	print $stats{'snvs_completed'} . " patients have SNVs completed\n";
	print $stats{'indels_completed'} . " patients have indels completed\n";
	
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

sub get_build_ids
{
	my $dir = shift(@_);
	
	my @build_ids = ();
	my $numBuilds = 0;
	
	my $dir_list = `ls -d $dir/build* 2>/dev/null`;
	chomp($dir_list);
	
	my @dir_lines = split(/\n/, $dir_list);
	foreach my $dir_line (@dir_lines)
	{
		my @lineContents = split(/\//, $dir_line);
		my $numContents = @lineContents;
		
		my $short_dir_name = $lineContents[$numContents - 1];
		
		my $build_id = $short_dir_name;
		$build_id =~ s/build//;
		$build_id =~ s/\@//;
		if($build_id)
		{
			$build_ids[$numBuilds] = $build_id;
			$numBuilds++;
		}
	}
	
	return(@build_ids);
}


1;

