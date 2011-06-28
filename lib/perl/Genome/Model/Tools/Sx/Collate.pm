package Genome::Model::Tools::Sx::Collate;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Collate {
    is  => 'Genome::Model::Tools::Sx',
};

sub help_brief {
    return <<HELP
    Collate sequences from different files to one
HELP
}

sub help_detail {
    return <<HELP
    This comand will collate sequences from different files to one. Use this to take a forward/ and reverse files and combine them into one, keeping the pairs together.
    
    Use as a stand alone to collate a file of sequences. This command cannot be used in a PIPE because commands in this directory handle sequecnes as a set. All sequences are handled as a set if a command is given 2 input files, or are reading from a PIPE that originally started with 2 input files. And, when the final write happens, there is only one output file, the sequences are automatically collated to it.
HELP
}

sub __errors__ {
    my $self = shift;
    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;

    if ( not $self->input or $self->input == 1 ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ input /],
            desc => 'Can only collate from at least 2 inputs',
        );
    }

    if ( not $self->output or $self->output != 1 ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ output /],
            desc => 'Can only collate to one output',
        );
    }

    return @errors;
}

1;

