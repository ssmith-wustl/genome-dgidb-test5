
package Genome::Model::Tools::Capture::GermlineModelGroup;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# ModelGroup - Build Genome Models for Germline Capture Datasets
#					
#	AUTHOR:		Will Schierding
#
#	CREATED:	2/09/2011 by W.S.
#	MODIFIED:	2/09/2011 by W.S.
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

my %already_reviewed = ();
my %wildtype_sites = my %germline_sites = ();

class Genome::Model::Tools::Capture::GermlineModelGroup {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		group_id		=> { is => 'Text', doc => "ID of model group" , is_optional => 0},
		output_build_dirs	=> { is => 'Text', doc => "If specified, outputs last succeeded build directory for each sample to this file" , is_optional => 1},
		output_coverage_stats	=> { is => 'Text', doc => "Specify a directory to output coverage stats" , is_optional => 1},
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

	## Save model ids by subject name ##
	
	my %succeeded_models_by_sample = ();

	## Output build dirs##
	
	if($self->output_build_dirs)
	{
		open(BUILDDIRS, ">" . $self->output_build_dirs) or die "Can't open outfile: $!\n";
	}

	## Open the output file ##
	if($self->output_coverage_stats) {
		open(OUTFILE, ">" . $self->output_coverage_stats) or die "Can't open output file: $!\n";
		print OUTFILE "Model_id\tBuild_id\tSubject_name\tBuild_Dir\tCoverage_Wingspan0_Depth20x\tPercent_Target_Space_Covered_20x\tPercent_Duplicates\tMapping_Rate\n";
	}

	## Get the models in each model group ##

	my $model_group = Genome::ModelGroup->get($group_id);
	my @models = $model_group->models; 

	foreach my $model (@models)
	{
		my $model_id = $model->genome_model_id;
		my $subject_name = $model->subject_name;
		$subject_name = "Model" . $model_id if(!$subject_name);
		
		if($model->last_succeeded_build_directory) {
			my $build = $model->last_succeeded_build;
			my $build_id = $build->id;
			$succeeded_models_by_sample{$subject_name} = $model_id;
			my $last_build_dir = $model->last_succeeded_build_directory;
			if($self->output_build_dirs) {
				print BUILDDIRS join("\t", $model_id, $subject_name, $build_id, "Succeeded", $last_build_dir) . "\n";
				unless($self->output_coverage_stats) {
					next;
				}
			}

			my ($duplicate_pct, $mark_dup_hash_ref);
			my $dup_metric = 'PERCENT_DUPLICATION';
			my @data = $model->instrument_data;
			my $length = @data;
			my $libname;
			if ($length > 1) {
				foreach my $possible (@data) {
					$libname = $possible->library_name;
					print join("\t", $model_id, $build_id, $subject_name, $last_build_dir, $libname) . "\n";
				}
			}
			else {
				$libname = $model->instrument_data->library_name;
			}

			if (-e $build->rmdup_metrics_file) {
				$mark_dup_hash_ref = $build->mark_duplicates_library_metrics_hash_ref;
				$duplicate_pct = $mark_dup_hash_ref->{$libname}->{$dup_metric};
			}
			else {
				print $build->rmdup_metrics_file . " does not exist\n";
				$duplicate_pct = "N/A";
			}

			my ($fs_stats, $mapping_pct);
			my $fs_pct = 'reads_mapped_percentage';
			my $flagstat_file = $build->whole_rmdup_bam_flagstat_file;
			if (-e $flagstat_file) {
				$fs_stats = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($flagstat_file);
				$mapping_pct = $fs_stats->{$fs_pct};
			}

			if($self->output_coverage_stats) {
				my $wingspan = 0;
				my $minimum_depth = 20;
				my $average_depth = 'mean_depth';
				my $target_space_covered = 'pc_target_space_covered';
				#raw metrics per ROI:
				#Column 13 is the min_depth_filter column.  If you want 20x stats only then grep or parse the file for 20 in column 13.   For a definition of the output format try 'gmt ref-cov standard --help'.
				my $wingspan_zero_stats_file = $build->stats_file($wingspan);
				if ($wingspan_zero_stats_file) {
					# summary of the coverage stats:
					my $wingspan_zero_summary_stats_file = $build->coverage_stats_summary_file($wingspan);
					# summary metrics for wingspan 0 and 20x minimum depth:
					my $hash_ref = $build->coverage_stats_summary_hash_ref;
#					print Data::Dumper::Dumper($hash_ref);
					my $summary_stats_ref = $hash_ref->{$wingspan}->{$minimum_depth}->{$average_depth};
					my $summary_stats_ref2 = $hash_ref->{$wingspan}->{$minimum_depth}->{$target_space_covered};
					print OUTFILE join("\t", $model_id, $build_id, $subject_name, $last_build_dir, $summary_stats_ref, $summary_stats_ref2, $duplicate_pct, $mapping_pct) . "\n";
				}
				else {
					print OUTFILE join("\t", $model_id, $build_id, $subject_name, $last_build_dir, "N/A", "N/A", $duplicate_pct, $mapping_pct) . "\n";
				}
			}

#SNP array concordance
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

