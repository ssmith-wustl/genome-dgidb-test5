package Genome::Utility::Diff;

use strict;
use warnings;
use Data::Dumper;

use Finfo::Std;

use IO::File;

#attributes

my %file  :name(file:r) :isa(file_r);
my %io  :name(_io:p);

sub START{
    my $self = shift;
    my $io = IO::File->new('< '.$self->file);
    $self->fatal_msg("couldn't open io") unless $io;
    $self->_io($io);
    1;
}

sub next_diff{
    my $self = shift;
    my %diff;
    my $line = $self->_io->getline;
    return undef unless $line;
    my $line_copy = $line;
    my ($subject, $chromosome, $pos, $ref, $patch) = split(/\s+/, $line);
    $diff{line} = $line_copy;
    $diff{subject} = $subject;
    $diff{chromosome} = $chromosome;
    $diff{position} = $pos;
    $diff{header} = $self->_generate_header($subject, $chromosome);
    $diff{ref} = $ref unless $ref =~/-/;
    $diff{patch} = $patch unless $patch =~/-/;

    return \%diff;
}

sub _generate_header{
    my ($self, $subject, $chromosome) = @_;
    return $subject;#TODO this only applies for human, need a more generalized method

}
1;
