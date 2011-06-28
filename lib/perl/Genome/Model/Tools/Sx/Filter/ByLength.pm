package Genome::Model::Tools::Sx::Filter::ByLength;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::Sx::Filter::ByLength {
    is => 'Genome::Model::Tools::Sx::Filter',
    has => [
        filter_length => {
            is => 'Number',
            doc => 'The number of bases to filter',
        }    
    ],
};

sub help_synopsis {
    return <<HELP
    Filter fastq sequences by length. Considers all sequences in the set.
HELP
}

sub __errors__ {
    my $self = shift;

    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;

    my $length = $self->filter_length;
    if ( defined $length and ( $length !~ /^$RE{num}{int}$/ or $length < 1 ) ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ filter_length /],
            desc => "Filter length ($length) must be a positive integer greater than 1",
        );
    }

    return @errors;
}

sub _create_filters {
    my $self = shift;

    my $length = $self->filter_length;
    return sub{
        my $seqs = shift;
        for my $seq ( @$seqs ) {
            unless ( length $seq->{seq} > $length ) {
                return;
            }
        }
        return 1;
    }
}

1;

