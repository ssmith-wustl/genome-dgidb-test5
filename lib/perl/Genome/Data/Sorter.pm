package Genome::Data::Sorter;

use strict;
use warnings;

use Genome::Data::IO;
use Genome::Data::IO::Reader;
use Genome::Data::IO::Writer;

sub create {
    my ($class, %params) = @_;
    my $self = {};
    bless ($self, $class);

    my $format = delete $params{format};
    unless ($format) {
        Carp::confess "Not given format!";
    }
    $self->format($format);

    my $input_file = delete $params{input_file};
    unless ($input_file) {
        Carp::confess "Not given input file!";
    }
    $self->input_file($input_file);

    my $output_file = delete $params{output_file};
    unless ($output_file) {
        Carp::confess "Not given output file!";
    }
    $self->output_file($output_file);

    my $sort_by = delete $params{sort_by};
    unless ($sort_by) {
        Carp::confess "Not given a property to sort by!";
    }
    $self->sort_by($sort_by);

    return $self;
}

sub format {
    my ($self, $format) = @_;
    if ($format) {
        $self->{_format} = $format;
    }
    return $self->{_format};
}

sub input_file {
    my ($self, $file) = @_;
    if ($file) {
        $self->{_input_file} = $file;
    }
    return $self->{_input_file};
}

sub output_file {
    my ($self, $file) = @_;
    if ($file) {
        $self->{_output_file} = $file;
    }
    return $self->{_output_file};
}

sub sort_by {
    my ($self, $property) = @_;
    if ($property) {
        my $reader = $self->_reader_for_input;
        my $produces = $reader->produces;
        unless ($produces and $produces->can($property)) {
            Carp::confess "Class $produces cannot be sorted by property $property, that property does not exist!";
        }
        $self->{_sort_by} = $property;
    }
    return $self->{_sort_by};
}

sub sort {
    my $self = shift;
    my $reader = $self->_reader_for_input;
    my @data = $reader->slurp;

    my $property = $self->sort_by;
    @data = sort {$a->$property cmp $b->$property} @data;

    my $writer = $self->_writer_for_output;
    $writer->write(@data);
    
    return 1;
}

sub _reader_for_input {
    my $self = shift;
    unless ($self->{_reader}) {
        my $reader = Genome::Data::IO::Reader->create(
            file => $self->input_file,
            format => $self->format,
        );
        $self->{_reader} = $reader;
    }
    return $self->{_reader};
}

sub _writer_for_output {
    my $self = shift;
    unless ($self->{_writer}) {
        my $writer = Genome::Data::IO::Writer->create(
            file => $self->output_file,
            format => $self->format,
        );
        $self->{_writer} = $writer;
    }
    return $self->{_writer};
}

1;

