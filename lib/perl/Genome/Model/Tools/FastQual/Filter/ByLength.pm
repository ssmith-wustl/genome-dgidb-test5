package Genome::Model::Tools::FastQual::Filter::ByLength;

use strict;
use warnings;

use Genome;            

require Carp;
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Tools::FastQual::Filter::ByLength {
    is => 'Genome::Model::Tools::FastQual::Filter',
    has => [
        filter_length => {
            is => 'Number',
            doc => 'the number of bases to filter',
        }    
    ],
};

sub help_synopsis {
    return <<HELP
    Filter fastq sequences by length. Considers all sequences in the set.
HELP
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    # Validate filter length
    my $filter_length = $self->filter_length;
    unless ( defined $filter_length ) {
        $self->error_message("No filter length given.");
        $self->delete;
        return;
    }

    unless ( $filter_length =~ /^$RE{num}{int}$/ and $filter_length > 1 ) {
        $self->error_message("Invalid filter length ($filter_length) given.");
        $self->delete;
        return;
    }

    return $self;
}

sub _filter {
    my ($self, $seqs) = @_;

    for my $seq ( @$seqs ) {
        unless ( length $seq->{seq} > $self->filter_length ) {
            return;
        }
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
