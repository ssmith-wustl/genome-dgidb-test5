package Genome::Model::Tools::FastQual::SeqWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::SeqWriter {
    is_abstract => 1,
    has => [
        files => { is => 'Text', is_many => 1, },
        _fhs => { is_optional => 1, is_many => 1, }, 
        metrics => { is_optional => 1, },
        _max_files => { value => 2, },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my @files = $self->files;
    if ( not @files ) {
        Carp::confess("No files given");
    }
    elsif ( @files > $self->_max_files ) {
        Carp::confess('Too many files given. Can only accept up to '.$self->_max_files);
    }
    elsif ( grep { $_ eq '-' } @files and @files > 1 ) {
        $self->error_message('Cannot read from STDIN and a file');
        return;
    }

    my  @fhs;
    for my $file ( @files ) {
        my $fh = eval{ Genome::Sys->open_file_for_appending($file); };
        if ( not $fh ) {
            $self->error_message('Failed to open file: '.$@);
            return;
        }
        push @fhs, $fh;
    }
    $self->_fhs(\@fhs);

    return $self;
}

sub write {
    my ($self, $seqs) = @_;
    $self->metrics->add($seqs) if $self->metrics;
    return $self->_write($seqs);
}

sub flush {
    my $self = shift;
    for my $fh ( $self->_fhs ) { $fh->flush; }
    return 1;
}

1;

