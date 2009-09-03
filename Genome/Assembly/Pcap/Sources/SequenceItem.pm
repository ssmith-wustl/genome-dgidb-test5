package Genome::Assembly::Pcap::Sources::SequenceItem;
our $VERSION = 0.01;

use strict;

use warnings;
use Carp;
use Storable;
use Genome::Assembly::Pcap::Transform;
use base(qw(Genome::Assembly::Pcap::Sources::Item));

sub new {
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %args) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = \%args;
    bless ($self, $class);		
	     
    return $self;
}

sub get_map {
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub length 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub sequence
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

1;
