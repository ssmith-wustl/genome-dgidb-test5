package Genome::Model::Tools::FastQual::FastqWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::FastqWriter {
    is => 'Genome::Model::Tools::FastQual::SeqReaderWriter',
    has => [
        _fhs => { is_optional => 1, is_many => 1, }, 
        _write_strategy => { is_optional => 1, },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my @files = $self->files;
    if ( not @files ) {
        Carp::confess("No fastq files given");
    }
    elsif ( @files > 2 ) {
        Carp::confess('Too many fastq files given to write');
    }

    my @fhs;
    for my $file ( @files ) {
        my $fh = eval{ Genome::Sys->open_file_for_appending($file); };
        if ( not $fh ) {
            $self->error_message('Failed to open fastq file: '.$@);
            return;
        }
        $fh->autoflush(1);
        push @fhs, $fh;
    }
    $self->_fhs(\@fhs);
    $self->_write_strategy( 
        @fhs == 1 ? '_collate' : '_separate'
    );

    return $self;
}

sub write {
    my ($self, $fastqs) = @_;

    Carp::confess("No fastqs to write") if not $fastqs;

    my $write_strategy = $self->_write_strategy;
    return $self->$write_strategy($fastqs);
}
    
sub _write {
    my ($self, $fh, $seq) = @_;

    $fh->print(
        join(
            "\n",
            '@'.$seq->{id}.( defined $seq->{desc} ? ' '.$seq->{desc} : '' ),
            $seq->{seq},
            '+',
            $seq->{qual},
        )."\n"
    );

    return 1;
}

sub _separate {
    my ($self, $fastqs) = @_;

    for my $i (0..1) {
        $self->_write(($self->_fhs)[$i], $fastqs->[$i])
            or Carp::confess("Can't write fastq: ".Dumper($fastqs->[$i]));
    }

    return 1;
}

sub _collate {
    my ($self, $fastqs)  = @_;

    my $fh = ($self->_fhs)[0];
    for my $fastq ( @$fastqs ) {
        $self->_write($fh, $fastq)
            or Carp::confess("Can't write fastq: ".Dumper($fastq));
    }

    return 1;
}

1;

