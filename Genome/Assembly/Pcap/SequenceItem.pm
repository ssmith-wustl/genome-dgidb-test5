package Genome::Assembly::Pcap::SequenceItem;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;
use Genome::Assembly::Pcap::Tag;
use Genome::Assembly::Pcap::Item;
#use Genome::Assembly::Pcap::Transform;
use Genome::Assembly::Pcap::Sequence;
use base (qw(Genome::Assembly::Pcap::Item));

my $pkg = "Genome::Assembly::Pcap::SequenceItem";
sub new {
    croak("$pkg:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = $class->SUPER::new(%params);
    #my $self = {};# = {%arg};
    bless ($self, $class);    
    
    #if(exists $params{sequence})
    #{
    #    $self->sequence($params{sequence});
    #}
    #else
    #{
    #    $self->sequence(Genome::Assembly::Pcap::Sequence->new(sequence_state => "invalid"));
    #}
	
	if(exists $params{callbacks})
	{
		$self->callbacks($params{callbacks});
	}
    return $self;
}

sub length #no setter for length, since it doesn't make sense to allow someone to set the length for an item that
#already has a length (i.e.  if you have a string ACTG, it doesn't make sense to set the length to anything other
#than 4, which is already implied
{
    my ($self,$type) =@_;
	
	if($self->sequence->_has_alignment)
    {
		return length($self->sequence->unpadded_base_string) if (defined $type && $type eq "unpadded");
        return length($self->sequence->padded_base_string);
    }
    elsif($self->sequence->unpadded_base_string)
    {
		warn "Sequence does not have alignment information!\n" if (defined $type && $type eq "padded");
        return length($self->sequence->unpadded_base_string);
    }
    else #invalid
    {
        return 0;
    }
}

sub sequence
{
	my ($self, $value) = @_;
    my ($name) = (caller(0))[3] =~ /.+::(.+)/;
    if(@_>1)
    {   
       return $self->check_and_load_data($name, $value);
    }
    my $sequence = $self->check_and_load_data($name);       
	return $sequence if defined $sequence;
	return $self->check_and_load_data($name,Genome::Assembly::Pcap::Sequence->new);
}

sub freeze
{
	my ($self) = @_;
	$self->SUPER::freeze;
	if($self->already_loaded("sequence"))
	{
		$self->sequence->freeze;
	}
}

sub thaw
{
	my ($self, $obj,$file_name, $fh) = @_;
	$self->SUPER::thaw($obj,$file_name, $fh);
	if($self->already_loaded("sequence"))
	{
		$self->sequence->thaw($obj,$file_name, $fh);
	}
}

1;
