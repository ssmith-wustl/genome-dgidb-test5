package Genome::Data::Converter;

use strict;
use warnings;

use Genome::Data::Reader;
use Genome::Data::Writer;

sub create {
    my ($class, %params) = @_;
    my $self = {};
    bless($self, $class);

    my $from_format = delete $params{from_format};
    unless ($from_format) {
        Carp::confess 'Not given from format!';
    }
    $self->from_format($from_format);

    my $from_file = delete $params{from_file};
    unless ($from_file) {
        Carp::confess 'Not given from file!';
    }
    $self->from_file($from_file);

    my $to_format = delete $params{to_format};
    unless ($to_format) {
        Carp::confess 'Not given to format!';
    }
    $self->to_format($to_format);

    my $to_file = delete $params{to_file};
    unless ($to_file) {
        Carp::confess 'Not given to file!';
    }
    $self->to_file($to_file);

    if (%params) {
        Carp::confess 'Extra parameters given to create method of ' . __PACKAGE__;
    }

    return $self;
}

sub from_format {
    my ($self, $format) = @_;
    if ($format) {
        $self->{_from_format} = $format;
    }
    return $self->{_from_format};
}

sub from_file {
    my ($self, $file) = @_;
    if ($file) {
        unless (-e $file) {
            Carp::confess "No file found at $file!";
        }
        $self->{_from_file} = $file;
    }
    return $self->{_from_file};
}

sub to_format {
    my ($self, $format) = @_;
    if ($format) {
        $self->{_to_format} = $format;
    }
    return $self->{_to_format};
}

sub to_file {
    my ($self, $file) = @_;
    if ($file) {
        $self->{_to_file} = $file;
    }
    return $self->{_to_file};
}

sub convert_all {
    my $self = shift;
    while ($self->convert_next) {};
    return 1;
}

sub convert_next {
    my $self = shift;
    my $from_reader = $self->_from_reader;
    my $to_writer = $self->_to_writer;
    my $object = $from_reader->next;
    $self->_set_current($object);
    if ($object) {
        $to_writer->write($object);
    }
    return $object;
}

sub current {
    my $self = shift;
    return $self->{_current};
}

sub _set_current {
    my ($self, $obj) = @_;
    $self->{_current} = $obj;
    return 1;
}

sub _from_reader {
    my $self = shift;
    unless ($self->{_from_reader}) {
        my $reader = Genome::Data::Reader->create(
            file => $self->from_file,
            format => $self->from_format,
        );
        unless ($reader) {
            Carp::confess 'Could not create reader for format ' .
                $self->from_format . ' and file ' . $self->from_file;
        }
        $self->{_from_reader} = $reader;
    }
    return $self->{_from_reader};
}

sub _to_writer {
    my $self = shift;
    unless ($self->{_to_writer}) {
        my $writer = Genome::Data::Writer->create(
            file => $self->to_file,
            format => $self->to_format,
        );
        unless ($writer) {
            Carp::confess 'Could not create writer for format ' .
                $self->to_format . ' and file ' . $self->to_file;
        }
        $self->{_to_writer} = $writer;
    }
    return $self->{_to_writer};
}

1;

