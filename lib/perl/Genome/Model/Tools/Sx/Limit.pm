package Genome::Model::Tools::Sx::Limit;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Limit {
    is  => 'Genome::Model::Tools::Sx',
    is_abstract => 1,
};

sub help_brief {
    return 'Limit sequences';
}

sub execute {
    my $self = shift;

    my $init = $self->_init;
    return if not $init;

    my $reader = $self->_reader;
    my $writer = $self->_writer;

    my @limiters = $self->_create_limiters;
    return if not @limiters;

    READER: while ( my $seqs = $reader->read ) {
        $writer->write($seqs);
        for my $limiter ( @limiters ) {
            last READER unless $limiter->($seqs); # returns 0 when done
        }
    }

    return 1;
}

1;

