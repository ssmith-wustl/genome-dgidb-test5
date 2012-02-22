package Genome::Model::MutationalSignificance::Command::CreateROI;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance::Command::CreateROI {
    is => ['Command::V2'],
    has_input => [
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation'
        },
    ],
    has_output => [
        roi_path => {
            is => 'String',
        },
    ],
};

sub execute {
    my $self = shift;

    my $feature_list = $self->annotation_build->get_or_create_roi_bed;

    unless ($feature_list) {
        $self->error_message('Could not create ROI file');
        return;
    }

    $self->roi_path($feature_list->file_path);

    $self->status_message('Created ROI file');

    return 1;
}

1;
