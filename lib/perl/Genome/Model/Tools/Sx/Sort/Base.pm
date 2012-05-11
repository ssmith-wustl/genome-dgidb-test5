package Genome::Model::Tools::Sx::Sort::Base;

use strict;
use warnings;

use Genome;

require IPC::Open2;

class Genome::Model::Tools::Sx::Sort::Base {
    is  => 'Genome::Model::Tools::Sx',
};

sub help_brief {
    return 'Sort sequences by average quality';
}

sub execute {
    my $self = shift;

    my $init = $self->_init;
    return if not $init;

    my $pid = IPC::Open2::open2(\*SORTED, \*UNSORTED, 'sort', $self->_sort_params);
    if ( not $pid ) {
        $self->error_message('Failed to create the sort command via open2');
        return;
    }

    my $flatten = $self->can('_flatten');
    my $inflate = $self->can('_inflate');

    my $reader = $self->_reader;
    while ( my $seqs = $reader->read ) {
        my $avg_qual = List::Util::sum( map { Genome::Model::Tools::Sx::Base->calculate_average_quality($_->{qual}) } @$seqs );
        print UNSORTED ($flatten->(@$seqs), "\n");
    }
    close UNSORTED;

    my $writer = $self->_writer;
    while ( my $line = <SORTED> ) {
        $writer->write( $inflate->($line) );
    }
    close SORTED;
    waitpid($pid, 0);

    return 1;
}

sub Xexecute { # old way, but might still need it
    my $self = shift;

    my $init = $self->_init;
    return if not $init;

    my $reader = $self->_reader;
    my $temp_fh = File::Temp->new() or die;
    no warnings 'uninitialized';
    while ( my $seqs = $reader->read ) {
        $temp_fh->print( _flatten(@$seqs)."\n" );
    }
    $temp_fh->flush;
    $temp_fh->close;

    my $writer = $self->_writer;
    my $sort_fh = IO::File->new("sort -nr -k 1 ".$temp_fh->filename." |") or die;
    while ( my $line = $sort_fh->getline ) {
        $writer->write( _inflate($line) );
    }

    return 1;
}

1;

