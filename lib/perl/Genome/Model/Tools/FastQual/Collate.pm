package Genome::Model::Tools::FastQual::Collate;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::FastQual::Collate {
    is  => 'Genome::Model::Tools::FastQual',
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

sub execute {
    my $self = shift;

    my $reader = $self->_open_reader
        or return;
    if ( $reader->isa('Genome::Utility::IO::StdinRefReader') ) {
        $self->error_message('Cannot read from a PIPE! Can only collate files!');
        return;
    }
    if ( scalar($reader->files) == 1 ) {
        $self->error_message("Cannot collate from one input file!");
        return;
    }

    my $writer = $self->_open_writer
        or return;
    if ( $writer->isa('Genome::Utility::IO::StdoutRefWriter') ) {
        $self->error_message('Cannot write to a PIPE! Can only collate files!');
        return;
    }
    unless ( scalar($writer->files) == 1 ) {
        $self->error_message("Cannot collate to more than one output file!");
        return;
    }

    while ( my $seqs = $reader->next ) {
        $writer->write($seqs);
    }

    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Tools/Fastq/Base.pm $
#$Id: Base.pm 60817 2010-07-09 16:10:34Z ebelter $
