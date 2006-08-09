package Bio::ContigUtilities::Item;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;
use base qw(Class::Accessor::Fast);
my $pkg = "Bio::ContigUtilities::Item";

Bio::ContigUtilities::Item->mk_accessors(qw(children name position length tags));

=pod

=head1 NAME

Item - Base class for Reads, Contigs, and SuperContigs (through SequenceItem).  This class is not used directly, but instead encapsulates low level functionality that is common to Reads, Contigs, and SuperContigs.

=head1 DESCRIPTION

Bio::ContigUtilities::Item has a position, length, tags, and children.  The data items can be set through accessor methods.

=head1 METHODS

=cut


=pod

=head1 new

$item = Bio::ContigUtilities::Item->new(children => \%children, tags => \@tags, position => $position, length => $length);
    
children - optional, a hash containing the items children, indexed by the child names.

tags - optional, an array of tags belonging to the item.

position - optional, the position of the item in the parent string.

length - optional, the length of the item in the parent item in padded base units.

=cut

sub new {
    croak("$pkg:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};# = {%arg};
    bless ($self, $class);    
    
    if(exists $params{children})
    {
        $self->children ( $params{children});
    }
    if(exists $params{tags})
    {
        $self->tags ($params{tags});
    }
    else
    {
        $self->tags ([]);
    }
    if(exists $params{position})
    {
        $self->{position} = $params{position};
    }
    else
    {
        $self->{position} = 1;
    }
    if(exists $params{length})
    {
        $self->{length} = $params{length};    
    }
    else
    {
        $self->{length} = 0;
    }
    return $self;
}

=pod

=head1 copy

$item->copy($item)           

This returns a deep copy of the $item.

=cut

sub copy
{
    my ($self) = @_;
    
    my $new_item = $self->new;
    $new_item->name ( $self->name);
    
    $new_item->tags ( [map { $self->copy_tag($_) } @{$self->{tags}}]);
    $new_item->children ( { map {$_->name, $_->copy($_)} values %{$self->{children}} });
    $new_item->position ( $self->position);
    $new_item->length ( $self->length);
    return $new_item;
}

=pod

=head1 add_tag
    
$item->add_tag($tag)           

This adds a tag to the item's list of tags.

=cut

sub add_tag
{
    my ($self, $tag) = @_;
    
    push @{$self->tags}, $tag;
}    

=pod

=head1 copy_tag

$item->copy_tag($tag)           

This returns a copy of the tag.

=cut

sub copy_tag #this function is a no-op that needs to be over-written by it's children when they are
             #implemented, in c++, it would be an abstract virtual method
{
    return undef;
}

# a couple of extra functions that will mimic functionality in GSC::Sequence::Item
#

=pod

=head1 start_position

$item->start_position           

This is a getter for the item's start position in the parent in padded units.

=cut 

sub start_position
{
    my ($self, $start_position) = @_;
    
    return $self->{position};
}
=pod

=head1 add_tag

$item->end_position           

This is a getter for the item's end position in the parent in padded units.

=cut 
sub end_position 
{
    my ($self) = @_;
    
    return $self->{position}+$self->length;    
}

1;
