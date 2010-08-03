package Genome::Model::Command::ListExpunged;

use strict;
use warnings;
use Genome;
use Carp;

class Genome::Model::Command::ListExpunged {
    is => 'Genome::Model::Command',
    doc => 'Lists any expunged data assigned to the model',
};

sub help_detail {
    return "Lists any expunged data assigned to the model";
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    unless ($model) {
        croak "Could not get model!";
    }

    my @assignments = $model->instrument_data_assignments;

    my @expunged;
    for my $assignment (@assignments) {
        my $instrument_data = $assignment->instrument_data;
        unless (defined $instrument_data) {
            push @expunged, $assignment;
        }
    }

    if (@expunged) {
        $self->status_message("Found " . scalar @expunged . " assignments with missing instrument data!" .
            "Instrument data IDs are below:\n" . join("\n", map { $_->instrument_data_id } @expunged));
    }
    else {
        $self->status_message("All assignments could find their respective instrument data!");
    }

    return 1;
}

1;

