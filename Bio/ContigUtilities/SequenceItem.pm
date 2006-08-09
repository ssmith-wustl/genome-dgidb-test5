package Bio::ContigUtilities::SequenceItem;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Bio::ContigUtilities::Item;
#use Bio::ContigUtilities::Transform;
use Bio::ContigUtilities::Sequence;
use base (qw(Bio::ContigUtilities::Item));
Bio::ContigUtilities::SequenceItem->mk_accessors(qw(sequence));

my $pkg = "Bio::ContigUtilities::SequenceItem";
sub new {
    croak("$pkg:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = $class->SUPER::new(%params);
    #my $self = {};# = {%arg};
    bless ($self, $class);    
    
    if(exists $params{sequence})
    {
        $self->sequence($params{sequence});
    }
    else
    {
        $self->sequence(Bio::ContigUtilities::Sequence->new(sequence_state => "invalid"));
    }
    return $self;
}

sub copy {
    my ($self) = @_;
    
    my $copy = $self->SUPER::copy($self);
    
    $copy->sequence ($self->sequence->copy($self->sequence));
    
    return $copy;   
    
}

sub length #no setter for length, since it doesn't make sense to allow someone to set the length for an item that
#already has a length (i.e.  if you have a string ACTG, it doesn't make sense to set the length to anything other
#than 4, which is already implied
{
    my ($self) =@_;

    if($self->sequence->get_sequence_state eq "padded")
    {
        return length($self->sequence->padded_base_string);
    }
    elsif($self->sequence->get_sequence_state eq "unpadded")
    {
        return length($self->sequence->unpadded_base_string);
    }
    else #invalid
    {
        return 0;
    }
}

1;
