package Genome::Model::SomaticValidation::Command::AlignReads;

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticValidation::Command::AlignReads {
    is => 'Command::V2',
    has_input => [
        build_id => {
            is => 'Number',
            doc => 'id of build for whcih to run alignments',
        },
    ],
    has => [
        build => {
            is => 'Genome::Model::Build',
            id_by => 'build_id',
            doc => 'build for which to run alignments',
        },
    ],
    has_transient_optional_output => [
        merged_alignment_result_id => {
            is => 'Number',
            doc => 'id of the merged alignment result for the instrument data',
        },
        control_merged_alignment_result_id => {
            is => 'Number',
            doc => 'id of the merged alignment result for the control instrument data',
        },
        merged_bam_path => {
            is => 'Text',
            doc => 'Path to the merged instrument data bam',
        },
        control_merged_bam_path => {
            is => 'Text',
            doc => 'Path to the merged control instrument data bam',
        },
    ],
    doc => 'align reads',
};

sub sub_command_category { 'pipeline steps' }

sub execute {
    my $self = shift;
    my $build = $self->build;

    my @instrument_data = $build->instrument_data;
    my $result = Genome::InstrumentData::Composite->get_or_create(
        inputs => {
            instrument_data => \@instrument_data,
            reference_sequence_build => $build->reference_sequence_build,
        },
        strategy => $build->processing_profile->alignment_strategy,
        log_directory => $build->log_directory,
    );

    my @bams = $result->bam_paths;
    unless(scalar(@bams) == scalar(@instrument_data)) {
        die $self->error_message('Found ' . scalar(@bams) . ' from alignment when ' . scalar(@instrument_data) . ' expected.');
    }

    $self->status_message("Alignment BAM paths:\n " . join("\n ", @bams));

    my @results = $result->_merged_results;
    for my $r (@results) {
        $r->add_user(label => 'uses', user => $build);
    }

    for my $r (@results) {
        my @i = $r->instrument_data;
        my $sample = $i[0]->sample;
        if($sample eq $build->tumor_sample) {
            $self->merged_alignment_result_id($r->id);
            $self->merged_bam_path($r->merged_alignment_bam_path);
        } elsif ($sample eq $build->normal_sample) {
            $self->control_merged_alignment_result_id($r->id);
            $self->control_merged_bam_path($r->merged_alignment_bam_path);
        }
    }

    return 1;
}

1;

