package Genome::Utility::Buffer;

use strict;
use warnings;
use Data::Dumper;

use Finfo::Std;

use IO::File;
#attributes

my %file :name(file:r) :type(file_r);
my %line_width :name(line_width:o) :type('int pos') :default(50);

my %io :name(_io:p);
my %count :name(_count:p);

sub START{
    my $self = shift;
    my $io = IO::File->new("> ".$self->file);
    $self->fatal_msg("can't create io") unless $io;
    $self->_io($io);
}

sub print_header{
    my ($self, $header) = @_;
    $self->_io->print("\n$header\n") or $self->fatal_msg("can't write header $header");
    return 1;
}

sub print{
    my ($self, $out) = @_;
    my @chars = split('',$out) or $self->fatal_msg("can't split output $out");
    $self->_print_char($_) foreach @chars;
}

sub _print_char{
    my ($self, $char) = @_;
    $self->_count(0) and $self->_io->print("\n") if $self->_count eq $self->line_width;
    $self->_io->print($char) and $self->_count($self->_count + 1);
}
