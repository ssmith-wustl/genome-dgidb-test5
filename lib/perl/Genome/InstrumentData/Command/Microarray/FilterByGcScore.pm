package Genome::InstrumentData::Command::Microarray::FilterByGcScore;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Microarray::FilterByGcScore {
    has => [
        min => {
            is => 'Text',
        },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    if ( not defined $self->min ) {
        $self->error_message("No min given to filter by gc score.");
        $self->delete;
        return;
    }

    if ( $self->min < 0 ) {
        $self->error_message("Invalid min (".$self->min.") given to filter by gc score.");
        $self->delete;
        return;
    }

    return $self;
}

sub filter {
    my ($self, $variant) = @_;

    return if defined $variant->{gc_score} and $variant->{gc_score} < $self->min; 

    return 1;
}

1;

