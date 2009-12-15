package Genome::Model::Event::Build::ReferenceAlignment::FindVariations::Pyroscan;

#REVIEW fdu
#Fix help info and align the parameter pairs to be more readable

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::FindVariations::Pyroscan {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::FindVariations'],
};

sub execute {
    my $self = shift;

    my $model = $self->model;

    # Collect the amplicon header files from all read sets
    my @assignment_events = $model->assignment_events;
    unless (scalar(@assignment_events)) {
        $self->error_message('No assignment events found for model '. $model->id );
        return;
    }
    my @amplicon_header_files;
    my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
    for my $assignment_event (@assignment_events) {
        my $amplicon_header_file = $assignment_event->amplicon_header_file;
        unless ($amplicon_header_file) {
            $self->error_message('Failed to find amplicon_header_file for event '. $assignment_event->id);
            return;
        }
        push @amplicon_header_files, $amplicon_header_file;
    }

    # Merge the amplicons from all read sets
    my $amplicon_merge = Genome::Model::Tools::Blat::MergeAmplicons->create(
                                                                            amplicon_files => \@amplicon_header_files,
                                                                            output_file => $self->build->amplicon_header_file,
                                                                        );
    unless ($amplicon_merge) {
        $self->error_message('Failed to create tool to merge amplicon header files');
        return;
    }
    unless ($amplicon_merge->execute) {
        $self->error_message('Failed to execute command '. $amplicon_merge->command_name);
        return;
    }

    my $cross_match_tool = Genome::Model::Tools::Blat::MatchToAmplicons->create(
        output_dir => $self->build->accumulated_alignments_directory,
        alignments_file => $self->build->merged_alignments_file .'.best-alignments.txt',
        headers_file => $self->build->amplicon_header_file,
        sample_name => $model->subject_name,
        sff_file => $self->build->merged_sff_file,
        run_crossmatch  => 1,
        overlap_bases  => 50,
    );
    unless ($cross_match_tool) {
        $self->error_message('Could not create cross match tool');
        return;
    }
    unless ($cross_match_tool->execute) {
        $self->error_message('Failed to execute command '. $cross_match_tool->command_name);
        return;
    }

    my $pyroscan_tool = Genome::Model::Tools::Blat::MatchToAmplicons->create(
        output_dir => $self->build->accumulated_alignments_directory,
        alignments_file => $self->build->merged_alignments_file .'.best-alignments.txt',
        headers_file => $self->build->amplicon_header_file,
        sample_name => $model->subject_name,
        run_pyroscan  => 1,
        overlap_bases  => 50,
        skip_refseq => 1,
    );

    unless ($pyroscan_tool) {
        $self->error_message('Could not create cross match tool');
        return;
    }
    unless ($pyroscan_tool->execute) {
        $self->error_message('Failed to execute command '. $pyroscan_tool->command_name);
        return;
    }

    my $convert_tool = Genome::Model::Tools::Blat::MatchToAmplicons->create(
        output_dir => $self->build->accumulated_alignments_directory,
        alignments_file => $self->build->merged_alignments_file .'.best-alignments.txt',
        headers_file => $self->build->amplicon_header_file,
        sample_name => $model->subject_name,
        convert_pyroscan  => 1,
        overlap_bases  => 50,
    );
    unless ($convert_tool) {
        $self->error_message('Could not create cross match tool');
        return;
    }
    unless ($convert_tool->execute) {
        $self->error_message('Failed to execute command '. $convert_tool->command_name);
        return;
    }
    return 1;
}


1;

