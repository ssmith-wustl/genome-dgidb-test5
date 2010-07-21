package Genome::Capture::Set::Command::DumpBedFile;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set::Command::DumpBedFile {
    is => 'Genome::Capture::Set::Command',
    has => [
        bed_file => { is => 'Text', doc => 'The path to dump BED coordinates for capture set',},
    ],
};

sub execute {
    my $self = shift;
    unless ($self->capture_set->print_bed_file($self->bed_file)) {
        $self->error_message('Failed to print bed file '. $self->bed_file);
        die($self->error_message);
    }
    return 1;
}


1;

