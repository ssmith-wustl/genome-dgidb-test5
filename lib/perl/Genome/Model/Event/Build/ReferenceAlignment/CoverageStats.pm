package Genome::Model::Event::Build::ReferenceAlignment::CoverageStats;

use strict;
use warnings;

use File::Path qw(rmtree);

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::CoverageStats {
    is => ['Genome::Model::Event'],
    has => [ ],
};

sub execute {
    my $self = shift;

    unless($self->_reference_sequence_matches) {
        die $self->error_message;
    }

    my $coverage_dir = $self->build->reference_coverage_directory;
    if (-d $coverage_dir) {
        #just remove the existing one to avoid shortcutting without verification...
        #TODO: Add verification and the ability to shortcut if output exists and is complete
        unless (rmtree($coverage_dir)) {
            $self->error_message('Failed to remove existing coverage directory '. $coverage_dir);
            die($self->error_message);
        }
    }
    unless (Genome::Sys->create_directory($coverage_dir)) {
        $self->error_message('Failed to create coverage directory '. $coverage_dir .":  $!");
        return;
    }
    my $bed_file = $self->build->region_of_interest_set_bed_file;
    my $log_file = $self->build->log_directory;
    my $bam_file = $self->build->whole_rmdup_bam_file;
    my $cmd = '/usr/bin/perl `which gmt` bio-samtools coverage-stats --output-directory='. $coverage_dir .' --log-directory='. $log_file
        .' --bed-file='. $bed_file .' --bam-file='. $bam_file .' --minimum-depths='. $self->build->minimum_depths
            .' --wingspan-values='. $self->build->wingspan_values;
    #my %coverage_stats_params = (
    #    output_directory => $coverage_dir,
    #    log_directory => $log_file,
    #    bed_file => $bed_file,
    #    bam_file => $self->build->whole_rmdup_bam_file,
    #    minimum_depths => $self->build->minimum_depths,
    #    wingspan_values => $self->build->wingspan_values,
    #);

    my $minimum_base_quality = $self->build->minimum_base_quality;
    if (defined($minimum_base_quality)) {
        $cmd .= ' --minimum-base-quality='. $minimum_base_quality;
        #$coverage_stats_params{minimum_base_quality} = $minimum_base_quality;
    }
    my $minimum_mapping_quality = $self->build->minimum_mapping_quality;
    if (defined($minimum_mapping_quality)) {
        $cmd .= ' --minimum-mapping-quality='. $minimum_mapping_quality;
        #$coverage_stats_params{minimum_mapping_quality} = $minimum_mapping_quality;
    }
    #unless (Genome::Model::Tools::BioSamtools::CoverageStats->execute(%coverage_stats_params)) {
    #    $self->error_message('Failed to generate coverage stats with params: '.  Data::Dumper::Dumper(%coverage_stats_params));
    #    die($self->error_message);
    #}
    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$bed_file,$bam_file],
    );
    my $as_ref = $self->build->alignment_summary_hash_ref;
    unless ($as_ref) {
        $self->error_message('Failed to load the alignment summary metrics!');
        die($self->error_message);
    }
    my $cov_ref = $self->build->coverage_stats_summary_hash_ref;
    unless ($cov_ref) {
        $self->error_message('Failed to load the coverage summary metrics!');
        die($self->error_message);
    }
    return 1;
}

#TODO This should probably be moved up to __errors__ in Genome::Model::ReferenceAlignment
#but keeping it here allows the rest of the process to this point to run...
sub _reference_sequence_matches {
    my $self = shift;

    my $roi_list = $self->model->region_of_interest_set;
    my $roi_reference = $roi_list->reference;
    my $reference = $self->model->reference_sequence_build;

    unless($roi_reference) {
        $self->error_message('no reference set on region of interest ' . $roi_list->name);
        return;
    }

    unless ($roi_reference->is_compatible_with($reference)) {
        if(Genome::Model::Build::ReferenceSequence::Converter->get(source_reference_build => $roi_reference, destination_reference_build => $reference)) {
            $self->status_message('Will run converter on ROI list.');
        } else {
            $self->error_message('reference sequence: ' . $reference->name . ' does not match the reference on the region of interest: ' . $roi_reference->name);
            return;
        }
    }

    return 1;
}

1;
