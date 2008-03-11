package Genome::Utility::DiffStream;

use strict;
use warnings;
use Data::Dumper;

use IO::File;

#attributes

sub new{
    my ($class, $file) = @_;
    my $io = IO::File->new('< '.$file);
    die "couldn't open io" unless $io;
    return bless({_io => $io}, $class);
}

sub next_diff{
    my $self = shift;
    my %diff;
    my $line = $self->{_io}->getline;
    return undef unless $line;
    my $line_copy = $line;
    my ($subject, $chromosome, $pos, $ref, $patch) = split(/\s+/, $line);
    $diff{line} = $line_copy;
    $diff{subject} = $subject;
    $diff{chromosome} = $chromosome;
    $diff{position} = $pos;
    $diff{header} = $subject;
    #$diff{header} = $self->_generate_header($subject, $chromosome);
    $diff{ref} = $ref unless $ref =~/-/;
    $diff{patch} = $patch unless $patch =~/-/;

    $diff{position}=$diff{position}-1 if $diff{ref}; # deletes now start AFTER index, like inserts
    return \%diff;
}

sub _generate_header{
    my ($self, $subject, $chromosome) = @_;
    return $subject;#TODO this only applies for human, need a more generalized method

}
1;
