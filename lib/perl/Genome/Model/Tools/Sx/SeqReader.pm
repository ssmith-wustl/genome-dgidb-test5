package Genome::Model::Tools::FastQual::SeqReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::SeqReader {
    is_abstract => 1,
    has => [
        files => { is => 'Text', is_many => 1, },
        _fhs => { is_optional => 1, is_many => 1, }, 
        metrics => { is_optional => 1, },
        is_paired => { is => 'Boolean', is_optional => 1, default_value => 0, }, # only for fastq for now
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
        my $fh = eval{ Genome::Sys->open_file_for_reading($file); };
        if ( not $fh ) {
            $self->error_message('Failed to open file: '.$@);
            return;
        }
        push @fhs, $fh;
    }
    $self->_fhs(\@fhs);

    return $self;
}

sub read {
    my ($self) = @_;
    my $seqs = $self->_read;
    return if not $seqs;
    $self->metrics->add($seqs) if $seqs and $self->metrics;
    return $seqs;
}

1;

