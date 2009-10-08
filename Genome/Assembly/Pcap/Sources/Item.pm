package Genome::Assembly::Pcap::Sources::Item;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

sub new 
{
	my $name = (caller(0))[3];
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
	my ($caller, %params) = @_; 
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;      
	my $self = \%params; 
	bless ($self, $class);
	return $self;
}

sub freeze
{
	my ($self) = @_;
	$self->{fh} = undef;
	$self->{reader}->{'input'} = undef;
}

sub thaw
{
	my ($self, $obj, $file_name, $fh) = @_;
	if(defined $file_name && $file_name eq $self->{file_name})
	{
		$self->{fh} = $fh;
	}
	else
	{
		$self->{fh} = $obj->get_fh($self->{file_name});
	}
	$self->{reader}->{'input'} = $self->{fh};
}

sub get_map {
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";	
}

sub children 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";	
}

sub name 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub position 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";	
}


sub length 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub tags
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub copy
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub add_tag
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
} 

sub copy_tag 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub start_position
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub end_position 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

1;
