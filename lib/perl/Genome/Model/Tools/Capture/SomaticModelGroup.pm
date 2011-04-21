
package Genome::Model::Tools::Capture::SomaticModelGroup;     # rename this when you give the module file a different name <--

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
my %included_variants = ();

my %already_reviewed = ();
my %passed_sites = my %wildtype_sites = my %germline_sites = ();
my $maf_header = "";
my $maf_header_printed = 0;

class Genome::Model::Tools::Capture::SomaticModelGroup {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		group_id		=> { is => 'Text', doc => "ID of model group" , is_optional => 0},
		output_build_dirs	=> { is => 'Text', doc => "If specified, outputs last succeeded build directory for each sample to this file" , is_optional => 1},
		output_review	=> 	{ is => 'Text', doc => "Specify a directory to output SNV/indel files for manual review" , is_optional => 1},
		output_maf_file	=> 	{ is => 'Text', doc => "Output a MAF file for downstream analysis" , is_optional => 1},
		review_database_snvs	=> 	{ is => 'Text', doc => "If provided, use to exclude already-reviewed sites" , is_optional => 1},
		review_database_indels	=> 	{ is => 'Text', doc => "If provided, use to exclude already-reviewed indels" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Operate on capture somatic model groups"                 
}

sub help_synopsis {
    return <<EOS
Operate on capture somatic model groups
EXAMPLE:	gmt capture somatic-model-group --group-id 3328
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


	## Reset Statistics 
	$stats{'review_snvs_possible'} = $stats{'review_snvs_already'} = $stats{'review_snvs_already_wildtype'} = $stats{'review_snvs_already_germline'} = $stats{'review_snvs_filtered'} = $stats{'review_snvs_included'} = 0;
	$stats{'review_indels_possible'} = $stats{'review_indels_already'} = $stats{'review_indels_already_wildtype'} = $stats{'review_indels_already_germline'} = $stats{'review_indels_filtered'} = $stats{'review_indels_included'} = 0;


	if($self->review_database_snvs)
	{
		load_review_database($self->review_database_snvs);
	}
	
	if($self->review_database_indels)
	{
		load_review_database($self->review_database_indels);
	}


	
	## Save model ids by subject name ##
	
	my %succeeded_models_by_sample = ();

	## Output build dirs##
	
	if($self->output_build_dirs)
	{
		open(BUILDDIRS, ">" . $self->output_build_dirs) or die "Can't open outfile: $!\n";
	}

	if($self->output_maf_file)
	{
		open(MAF, ">" . $self->output_maf_file) or die "Can't open MAF file: $!\n";
	}

	## Get the models in each model group ##

	my $model_group = Genome::ModelGroup->get($group_id);
	my @models = $model_group->models; 

	foreach my $model (@models)
	{
		$stats{'models_in_group'}++;
		
		my $model_id = $model->genome_model_id;
		my $subject_name = $model->subject_name;
		$subject_name = "Model" . $model_id if(!$subject_name);
		
		my $last_build_dir = "";
		my $model_status = "New";
		my $final_build_result = "";
		my $last_build_id = 0;

		my $num_builds = 0;		
		my $num_maf_mutations = 0;

		my $build_ids = my $build_statuses = "";
		my @builds = $model->builds;

		if(@builds)
		{
			$model_status = "Building";

			foreach my $build (@builds)
			{
				my $build_id = $build->id;
				my $build_status = $build->status;
				my $build_dir = $build->data_directory;

				$build_ids .= "," if($build_ids);
				$build_statuses .= "," if($build_statuses);

				$build_ids .= $build_id;
				$build_statuses .= $build_status;
				
				if($model_status eq "New" || $build_status eq "Succeeded" || $build_status eq "Running")
				{
					$model_status = $build_status;
					$last_build_dir = $build_dir;
				}
			}

			if($model->last_succeeded_build_directory)
			{
				$model_status = "Succeeded";	## Override if we have successful build dir ##				
				$succeeded_models_by_sample{$subject_name} = $model_id;
				$last_build_dir = $model->last_succeeded_build_directory;
				if($self->output_build_dirs)
				{
					print BUILDDIRS join("\t", $subject_name, $last_build_dir) . "\n";					
				}

				
				my %build_results = get_build_results($last_build_dir);
				$final_build_result = $build_results{'tier1_snvs'} . " Tier1 SNVs, " . $build_results{'tier1_indels'} . " Tier1 Indels, ";

				if($self->output_review)
				{
					my $tumor_model = $model->tumor_model;
					my $normal_model = $model->normal_model;
					my $tumor_model_dir = $tumor_model->last_succeeded_build_directory;
					my $normal_model_dir = $normal_model->last_succeeded_build_directory;
					my $tumor_bam = `ls $tumor_model_dir/alignments/*.bam`; chomp($tumor_bam);
					my $normal_bam = `ls $normal_model_dir/alignments/*.bam`; chomp($normal_bam);
					
					my $tier1_snvs = $last_build_dir . "/merged.somatic.snp.filter.novel.tier1";
					my $output_tier1_snvs = $self->output_review . "/" . $subject_name . ".$model_id.SNVs.tsv";
					output_snvs_for_review($model_id, $tier1_snvs, $output_tier1_snvs, $subject_name, $normal_bam, $tumor_bam);

					my $tier1_gatk = $last_build_dir . "/gatk.output.indel.formatted.Somatic.tier1";
					my $tier1_indels = $last_build_dir . "/merged.somatic.indel.filter.tier1";
					my $output_tier1_indels = $self->output_review . "/" . $subject_name . ".$model_id.Indels.tsv";
					output_indels_for_review($model_id, $tier1_indels, $tier1_gatk, $output_tier1_indels, $subject_name, $normal_bam, $tumor_bam);
				}
				
				if($self->output_maf_file)
				{
					my $sample_maf_file = $last_build_dir . "/tcga-maf.tsv";
					if(-e $sample_maf_file)
					{
						my $sample_maf_results = parse_maf_file($subject_name, $sample_maf_file);
						my @sample_results = split(/\n/, $sample_maf_results);
						$num_maf_mutations = @sample_results;
						
						if($maf_header && !$maf_header_printed)
						{
							print MAF "$maf_header\n";
							$maf_header_printed = 1;
						}
						print MAF "$sample_maf_results\n";
					}

				}

				
			}

		}

		print join("\t", $model_id, $subject_name, $model_status, $build_ids, $build_statuses, $final_build_result, $num_maf_mutations . " mutations added to MAF") . "\n";

	}	
	
	print $stats{'models_in_group'} . " models in group\n" if($stats{'models_in_group'});
	print $stats{'models_running'} . " models running\n" if($stats{'models_running'});
	print $stats{'models_finished'} . " models finished\n" if($stats{'models_finished'});

	if($self->output_review)
	{
		print $stats{'review_snvs_possible'} . " Tier 1 SNVs could be reviewed\n";
		print $stats{'review_snvs_already'} . " were already reviewed\n";
		print $stats{'review_snvs_already_wildtype'} . " were wild-type in another sample\n";
		print $stats{'review_snvs_already_germline'} . " were germline in at least 3 other samples\n";
		print $stats{'review_snvs_filtered'} . " were filtered as probable germline\n";
		print $stats{'review_snvs_included'} . " were included for review\n";
		print $stats{'review_snvs_already_included'} . " were duplicates and not counted twice\n";

		print $stats{'review_indels_possible'} . " Tier 1 Indels could be reviewed\n";
		print $stats{'review_indels_already'} . " were already reviewed\n";
		print $stats{'review_indels_already_wildtype'} . " were wild-type in another sample\n";
		print $stats{'review_indels_already_germline'} . " were germline in another sample\n";		
		print $stats{'review_indels_filtered'} . " were filtered as probable germline\n";
		print $stats{'review_indels_included'} . " were included for review\n";
	}


	close(MAF) if($self->output_maf_file);
}



################################################################################################
# Get Build Results - Summarize the progress/results of a given build
#
################################################################################################

sub parse_maf_file
{
	my $sample_name = shift(@_);
	my $FileName = shift(@_);

	my $sample_maf = "";

	## Column index for fields in MAF file ##
	
	my %column_index = ();
	my @columns = ();

	## Parse the Tier 1 SNVs file ##

	my $input = new FileHandle ($FileName);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		my @lineContents = split(/\t/, $line);
	
		if($lineCounter <= 2 && $line =~ "Chrom")
		{
			$maf_header = $line;
			
			## Parse the MAF header line to determine field locations ##	
			my $numContents = @lineContents;
			
			for(my $colCounter = 0; $colCounter < $numContents; $colCounter++)
			{
				if($lineContents[$colCounter])
				{
					$column_index{$lineContents[$colCounter]} = $colCounter;
				}
			}
			
			foreach my $column (keys %column_index)
			{
				## Print out the columns as parsed ##
				#print "$column_index{$column}\t$column\n";
				$columns[$column_index{$column}] = $column;	## Save the column order ##
			}
		}
		elsif($lineCounter < 2)
		{

		}
		elsif($lineCounter > 2 && !@columns)
		{
			die "No Header in MAF file!\n";
		}
		elsif($lineCounter > 2 && @columns)
		{
			## Build a record for this line, assigning all values to respective fields ##
			
			my %record = ();

			foreach my $column_name (keys %column_index)
			{
				my $column_number = $column_index{$column_name};
				$record{$column_name} = $lineContents[$column_number];
			}
			
			my $chrom = $record{'Chromosome'};
			my $chr_start = $record{'Start_position'};
			my $chr_stop = $record{'End_position'};
			my $ref_allele = $record{'Reference_Allele'};
			my $var_allele = $record{'Tumor_Seq_Allele2'};
			$var_allele = $record{'Tumor_Seq_Allele1'} if($var_allele eq $ref_allele);
			my $var_type = $record{'Variant_Type'};
			
			my @temp = split(/\-/, $sample_name);
			my $patient_id = join("-", "TCGA", $temp[1], $temp[2]);
			my $variant_key = join("\t", $patient_id, $chrom, $chr_start, $chr_stop); #, $ref_allele, $var_allele);
			
			## Include variant if it had a review-passed call, or if no reviews were loaded ##
			if($passed_sites{$variant_key} || !(%passed_sites))
			{
				$sample_maf .= "\n" if($sample_maf);
				$sample_maf .= $line;
			}
		}
	}
	
	close($input);
	
	return($sample_maf);
}


################################################################################################
# Get Build Results - Summarize the progress/results of a given build
#
################################################################################################

sub get_build_results
{
	my $build_dir = shift(@_);
	my %results = ();
	
	my $tier1_snvs = $build_dir . "/merged.somatic.snp.filter.novel.tier1";
	my $tier1_gatk = $build_dir . "/gatk.output.indel.formatted.Somatic.tier1";
	my $tier1_indels = $build_dir . "/merged.somatic.indel.filter.tier1";
	
	## Check for Tier 1 SNVs ##
	
	if(-e $tier1_snvs)
	{
		## Get count ##
		my $count = `cat $tier1_snvs | wc -l`;
		chomp($count);
		$results{'tier1_snvs'} = $count;
	}
	
	if(-e $tier1_indels)
	{
		my $count = `cat $tier1_indels $tier1_gatk | cut --fields=1-3 | sort -u | wc -l`;
		chomp($count);

		$results{'tier1_indels'} = $count;
	}
	
	return(%results);
}





################################################################################################
# Get Build Results - Summarize the progress/results of a given build
#
################################################################################################

sub get_build_progress
{
	my $build_dir = shift(@_);
	my %results = ();
	
	my $tier1_snvs = $build_dir . "/merged.somatic.snp.filter.novel.tier1";
	my $tier1_gatk = $build_dir . "/gatk.output.indel.formatted.Somatic.tier1";
	my $tier1_indels = $build_dir . "/merged.somatic.indel.filter.tier1";
	
	## Check for Tier 1 SNVs ##
	
	if(-e $tier1_snvs)
	{
		$results{'tier1_snvs_done'} = 1;
		## Get count ##
		my $count = `cat $tier1_snvs | wc -l`;
		chomp($count);
		$results{'num_tier1_snvs'} = $count;
	}
	
	return(%results);
}


################################################################################################
# Get Build Results - Summarize the progress/results of a given build
#
################################################################################################

sub load_review_database
{
	my $FileName = shift(@_);

	## Parse the Tier 1 SNVs file ##

	my $input = new FileHandle ($FileName);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		my ($model_id, $build_id, $sample_name, $chrom, $chr_start, $chr_stop, $ref, $var, $code) = split(/\t/, $line);
		
		my $key = join("\t", $model_id, $chrom, $chr_start, $chr_stop);
		$already_reviewed{$key} = $code;

		if($code eq "O" || $code eq "D" || $code eq "LQ")
		{
			my $key = join("\t", $chrom, $chr_start, $chr_stop, $ref, $var);
			$wildtype_sites{$key}++;
		}
		elsif($code eq "G")
		{
			my $key = join("\t", $chrom, $chr_start, $chr_stop, $ref, $var);
			$germline_sites{$key}++;			
		}
		elsif($code eq "S" || $code eq "V")
		{
			my @temp = split(/\-/, $sample_name);
			my $patient_id = join("-", "TCGA", $temp[1], $temp[2]);
			my $key = join("\t", $patient_id, $chrom, $chr_start, $chr_stop);
			$passed_sites{$key} = 1;
		}
	}
	
	close($input);
	
}



################################################################################################
# Get Build Results - Summarize the progress/results of a given build
#
################################################################################################

sub output_snvs_for_review
{
	my ($model_id, $variant_file, $output_file, $subject_name, $normal_bam, $tumor_bam) = @_;
	
	## Check for Tier 1 SNVs ##
	
	if(-e $variant_file)
	{
		## Open the output file ##
		
		open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";
		print OUTFILE join("\t", "TUMOR", $tumor_bam) . "\n";
		print OUTFILE join("\t", "NORMAL", $normal_bam) . "\n";
		print OUTFILE "chrom\tchr_start\tchr_stop\tref\tvar\tcode\tnote\n";
		
		## Parse the Tier 1 SNVs file ##
	
		my $input = new FileHandle ($variant_file);
		my $lineCounter = 0;
	
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;

			my ($chrom, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $line);
			my @lineContents = split(/\t/, $line);

			my $include_flag = 0;
			
			my $key = join("\t", $model_id, $chrom, $chr_start, $chr_stop);
			my $variant_key = join("\t", $chrom, $chr_start, $chr_stop, $ref, $var);
			my $sample_variant_key = join("\t", $subject_name, $variant_key);
			
			$stats{'review_snvs_possible'}++;
			
			if($already_reviewed{$key})
			{
				$include_flag = 0;
				$stats{'review_snvs_already'}++;
			}
			elsif($wildtype_sites{$variant_key})
			{
				$include_flag = 0;
				$stats{'review_snvs_already_wildtype'}++;
			}
			elsif($germline_sites{$variant_key} && $germline_sites{$variant_key} >= 3)
			{
				$include_flag = 0;
				$stats{'review_snvs_already_germline'}++;
			}
			elsif($included_variants{$sample_variant_key})
			{
				$include_flag = 0;
				$stats{'review_snvs_already_included'}++;				
			}
			else
			{
				## Sniper SNV/INS/DEL File ##
				
				if($lineContents[5] && ($lineContents[5] eq "SNP" || $lineContents[5] eq "INS" || $lineContents[5] eq "DEL"))
				{
					$include_flag = 1;
				}
				
				## VarScan File ##
				
				elsif($line =~ 'Somatic')
				{
					my $normal_freq = $lineContents[7];
					my $tumor_freq = $lineContents[11];
					$normal_freq =~ s/\%//g;
					$tumor_freq =~ s/\%//g;
					
					if($tumor_freq < 30 && $normal_freq >= 2)
					{
						## Exclude a possible Germline Event ##
						$stats{'review_snvs_filtered'}++;
					}
					else
					{
						$include_flag = 1;			
					}
				}
				
				## GATK Indel File ##
				
				elsif($line =~ 'OBS\_COUNTS')
				{
					$include_flag = 1;				
				}				
			}

			if($include_flag)
			{
				print OUTFILE join("\t", $chrom, $chr_start, $chr_stop, $ref, $var) . "\n";
				$stats{'review_snvs_included'}++;
				my $key = join("\t", $subject_name, $chrom, $chr_start, $chr_stop, $ref, $var);
				$included_variants{$sample_variant_key} = 1;
			}


		}
		
		close($input);
		
		
		close(OUTFILE);
		
	}

}



################################################################################################
# Get Build Results - Summarize the progress/results of a given build
#
################################################################################################

sub output_indels_for_review
{
	my ($model_id, $variant_file1, $variant_file2, $output_file) = @_;
	
	my %indels = ();
	
	## Check for Tier 1 SNVs ##
	
	if(-e $variant_file1)
	{
		## Parse the Tier 1 SNVs file ##
	
		my $input = new FileHandle ($variant_file1);
		my $lineCounter = 0;
	
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;

			my ($chrom, $chr_start) = split(/\t/, $line);
		
			$indels{"$chrom\t$chr_start"} .= "\n" if($indels{"$chrom\t$chr_start"});
			$indels{"$chrom\t$chr_start"} .= $line;
		}
		
		close($input);		
	}


	if(-e $variant_file2)
	{
		## Parse the Tier 1 SNVs file ##
	
		my $input = new FileHandle ($variant_file2);
		my $lineCounter = 0;
	
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;

			my ($chrom, $chr_start) = split(/\t/, $line);
		
			$indels{"$chrom\t$chr_start"} .= "\n" if($indels{"$chrom\t$chr_start"});
			$indels{"$chrom\t$chr_start"} .= $line;
		}
		
		close($input);		
	}


	## Open the output file ##
	
	open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";
	print OUTFILE "chrom\tchr_start\tchr_stop\tref\tvar\tcode\tnote\n";

	foreach my $key (sort byChrPos keys %indels)
	{
		my $include_flag = 0;
		
		my ($chrom, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $indels{$key});
		
		my $review_key = join("\t", $model_id, $chrom, $chr_start, $chr_stop);
		my $variant_key = join("\t", $chrom, $chr_start, $chr_stop, $ref, $var);
		
		my @indel_lines = split(/\n/, $indels{$key});
		my $num_indel_lines = @indel_lines;
		
		$stats{'review_indels_possible'}++;
		
		if($already_reviewed{$review_key})
		{
			## Skip already reviewed ##
			$stats{'review_indels_already'}++;
			$include_flag = 0;
		}
		elsif($wildtype_sites{$variant_key})
		{
			$include_flag = 0;
			$stats{'review_indels_already_wildtype'}++;
		}
		elsif($germline_sites{$variant_key} && $germline_sites{$variant_key} >= 3)
		{
			$include_flag = 0;
			$stats{'review_indels_already_germline'}++;
		}		
		elsif($indels{$key} =~ 'OBS\_COUNTS')
		{
			## GATK indel ##
			$include_flag = 1;
		}
		else
		{
			my $line = $indels{$key};
			my @lineContents = split(/\t/, $line);			

			## Sniper SNV/INS/DEL File ##
			
			if($lineContents[5] && ($lineContents[5] eq "SNP" || $lineContents[5] eq "INS" || $lineContents[5] eq "DEL"))
			{
				$include_flag = 1;
			}
			
			## VarScan File ##
			
			elsif($line =~ 'Somatic')
			{
				my $normal_freq = $lineContents[7];
				my $tumor_freq = $lineContents[11];
				$normal_freq =~ s/\%//g;
				$tumor_freq =~ s/\%//g;
				
				if($tumor_freq < 20 && $normal_freq >= 2)
				{
					$stats{'review_indels_filtered'}++;
				}
				else
				{
					$include_flag = 1;
				}
			}
		}
		
		if($include_flag)
		{
			print OUTFILE join("\t", $chrom, $chr_start, $chr_stop, $ref, $var) . "\n";
			$stats{'review_indels_included'}++;
		}
	}
	
	close(OUTFILE);


}



sub byChrPos
{
	my ($chr_a, $pos_a) = split(/\t/, $a);
	my ($chr_b, $pos_b) = split(/\t/, $b);
	
	$chr_a cmp $chr_b
	or
	$pos_a <=> $pos_b;
}


1;

