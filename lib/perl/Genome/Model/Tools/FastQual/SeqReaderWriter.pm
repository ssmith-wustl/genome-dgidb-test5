package Genome::Model::Tools::FastQual::SeqReaderWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::SeqReaderWriter {
    is_abstract => 1,
    has => [
        files => { is => 'Text', is_many => 1, },
        _fhs => { is_optional => 1, is_many => 1, }, 
        metrics => { is_optional => 1, },
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

    my $file_open_method = $self->_file_open_method;
    my  @fhs;
    for my $file ( @files ) {
        my $fh = eval{ Genome::Sys->$file_open_method($file); };
        if ( not $fh ) {
            $self->error_message('Failed to open file: '.$@);
            return;
        }
        $fh->autoflush(1);
        push @fhs, $fh;
    }
    $self->_fhs(\@fhs);

    return $self;
}

sub _max_files { 2; }
sub _file_open_method { 
    my $self = shift;

    my $class = $self->class;
    if ( $class =~ /Reader$/ ) {
        return 'open_file_for_reading';
    }
    elsif ( $class =~ /Writer$/ ) {
        return 'open_file_for_appending';
    }
    else {
        Carp::confess('Failed to derive file open method');
    }
}

sub write {
    my ($self, $seqs) = @_;
    $self->metrics->add($seqs) if $self->metrics;
    return $self->_write($seqs);
}

sub read {
    my ($self) = @_;
    my $seqs = $self->_read;
    return if not $seqs;
    $self->metrics->add($seqs) if $seqs and $self->metrics;
    return $seqs;
}

1;

