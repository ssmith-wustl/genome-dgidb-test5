package Genome::Model::Tools::FastQual::Filter;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::FastQual::Filter {
    is  => 'Genome::Model::Tools::FastQual',
};

sub help_synopsis {
    return <<HELP
HELP
}

sub help_detail {
    return <<HELP 
HELP
}

sub execute {
    my $self = shift;

    my $reader = $self->_open_reader
        or return;
    my $writer = $self->_open_writer
        or return;

    while ( my $seqs = $reader->next ) {
        $self->_filter($seqs) or next;
        $writer->write($seqs);
    }

    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Tools/Fastq/Base.pm $
#$Id: Base.pm 60817 2010-07-09 16:10:34Z ebelter $
