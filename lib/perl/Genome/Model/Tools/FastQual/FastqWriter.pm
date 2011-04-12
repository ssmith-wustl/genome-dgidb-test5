package Genome::Model::Tools::FastQual::FastqWriter;

use strict;
use warnings;

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw/ id files _fhs _write_strategy /);

require Carp;
use Data::Dumper 'Dumper';
require Genome::Model::Tools::FastQual::FastqWriter;

my $id = 0;
sub create {
    my ($class, %params) = @_;

    my $self = bless \%params, $class;

    my $files = $self->files;
    unless ( defined $files ) {
        Carp::confess("No fastq files given");
    }
    unless ( ref $files ) {
        # be nice, set to aryref
        $files = $self->files([ $files ]);
    }

    if ( @$files == 0 ) {
        Carp::confess('No fastq files given to write');
    }
    elsif ( @$files > 2 ) {
        Carp::confess('Too many fastq files given to write');
    }

    my @fhs;
    for my $file ( @$files ) {
        my $fh = Genome::Sys->open_file_for_appending($file);
        unless ( $fh ) {
            Carp::confess("Can't open fastq file.");
        }
        $fh->autoflush(1);
        push @fhs, $fh;
    }
    $self->_fhs(\@fhs);
    $self->_write_strategy( 
        @fhs == 1 ? '_collate' : '_separate'
    );

    $self->id(++$id);

    return $self;
}

sub write {
    my ($self, $fastqs) = @_;

    unless ( $fastqs ) {
        Carp::confess("No fastqs to write");
    }

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
        $self->_write($self->_fhs->[$i], $fastqs->[$i])
            or Carp::confess("Can't write fastq: ".Dumper($fastqs->[$i]));
    }

    return 1;
}

sub _collate {
    my ($self, $fastqs)  = @_;

    my $fh = $self->_fhs->[0];
    for my $fastq ( @$fastqs ) {
        $self->_write($fh, $fastq)
            or Carp::confess("Can't write fastq: ".Dumper($fastq));
    }

    return 1;
}

1;

