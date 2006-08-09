package Bio::ContigUtilities::Contig;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Bio::ContigUtilities::SequenceItem;
use Bio::ContigUtilities::Sequence;
use base (qw(Bio::ContigUtilities::SequenceItem));

my $pkg = "Bio::ContigUtilities::Contig";

=pod

=head1 NAME

Contig - Contig Object.

=head1 SYNOPSIS

my $contig = Bio::ContigUtilities::Contig->new(reads => \%reads, base_segments => \@base_segments, ace_contig => $ace_contig,  contig_tags => \@contig_tags);

=head1 DESCRIPTION

Bio::ContigUtilities::Contig mainly acts a container for the reads and sequence data that are normally associated with contig.
It inherits some useful functionality from Bio::ContigUtilities::SequenceItem, which uses Bio::ContigUtilities::Sequence.

=head1 METHODS

=cut

sub new 
{
    croak("$pkg:new:no class given, quitting") if @_ < 1;
	my ($caller, %params) = @_; 
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = $class->SUPER::new(%params);
    
	my $ace_contig;    
    
    #eddie suggests to use delete
	
	if(exists $params{reads})
	{
		$self->children ($params{reads});
	}
	if(exists $params{base_segments})
	{
		$self->base_segments ($params{base_segments});
	}
	if(exists $params{contig_tags})
	{
		$self->tags ( $params{contig_tags});
	}
    if(exists $params{ace_contig})
    {
        $self->ace_contig ($params{ace_contig});
    }
        
    return $self;
}

=pod

=head1 ace_contig

$contig->ace_contig($ace_contig_hash);
    
This is a getter/setter that takes a contig hash that is created by GSC::IO::Assembly::Ace::Reader.  It will also return an ace contig hash using the data that is contained in the contig.

=cut

sub ace_contig
{
    my ($self, $ace_contig) = @_;

    if(@_ > 1)
    {
        $self->sequence ( Bio::ContigUtilities::Sequence->new( sequence_state => "padded",
                                                           padded_base_string => $ace_contig->{consensus},
                                                           complemented => ($ace_contig->{u_or_c} =~ /c/i or 0)
                                                         ));
        $self->sequence->unpadded_base_quality ( $ace_contig->{base_qualities}); 
        $self->name ($ace_contig->{name});
        $self->{type} = "contig";   
    }
    return { type => "contig",
             name => $self->{name},
             base_count => $self->length,
             read_count => scalar (keys %{$self->reads}),
             base_seg_count => scalar (@{$self->base_segments}),
             u_or_c => ( $self->complemented ? "C" : "U" ),
             consensus => $self->sequence->padded_base_string,
             base_qualities => $self->sequence->unpadded_base_quality
           };             
}

=pod

=head1 reads

$contig->reads(\%reads);
    
This is a getter/setter that will either get or set the Contig's hash of reads.

=cut

sub reads
{
	my ($self, $reads) = @_;

	$self->children = $reads if (@_ > 1);
	 
	return $self->children;
}

=pod

=head1 base_segments

$contig->base_segments(\@base_segments);
    
This is a getter/setter that will either get or set the Contig's array of base_segments.

=cut

sub base_segments
{
	my ($self, $base_segments) = @_;
	
	$self->{base_segments} = $base_segments if (@_ > 1);
	 
	return $self->{base_segments};
}

=pod

=head1 read_count

$contig->read_count;
    
This returns the count of reads.

=cut

sub read_count
{
	my ($self) = @_;
	
	return @{$self->children};
}

=pod

=head1 base_count

$contig->base_count;
    
This returns the number of unpadded bases.

=cut

sub base_count
{
	my ($self) = @_;

	return length $self->sequence->unpadded_base_string;
}

=pod

=head1 base_segment_count

my $bs_count = $contig->base_segment_count;
    
This returns the number of base segments.

=cut

sub base_segment_count
{
	my ($self) = @_;
	
	return @{$self->base_segments};
}

=pod

=head1 complemented

my $iscomplemented = $contig->complemented($iscomplemented);

=cut

sub complemented
{
	my ($self, $complemented) = @_;
	
	$self->sequence->complemented ($complemented) if (@_ > 1);
	
	return $self->sequence->complemented;
}

=pod

=head1 copy_base_segment

my $base_segment_copy = $contig->copy_base_segment($base_segment);
    
This function will copy a base_segment.

=cut

sub copy_base_segment
{
	my ($self, $base_segment) = @_;
	
	return { type => $base_segment->{type},
	         start_pos => $base_segment->{start_pos},
			 end_pos => $base_segment->{end_pos},
			 read_name => $base_segment->{read_name}};
}

=pod

=head1 copy_tag

my $tag_copy = $contig->copy_tag($contig_tag);
    
This copies a contig tag.

=cut

sub copy_tag
{
	my ($self, $contig_tag) = @_;
	
	return { type => $contig_tag->{type},
             contig_name => $contig_tag->{contig_name},
             tag_type => $contig_tag->{tag_type},
             program => $contig_tag->{program},
             start_pos => $contig_tag->{start_pos},
             end_pos => $contig_tag->{end_pos},
             date => $contig_tag->{date},
             no_trans => $contig_tag->{no_trans},
             data => $contig_tag->{data} };
}

=pod

=head1 copy

my $contig_copy = $contig->copy($contig);
    
This creates a deep copy of the contig.

=cut

sub copy
{
    my ($self) = @_;
        
    #copy parent
    my $contig = $self->SUPER::copy($self);
    $contig->base_segments ( [map { $self->copy_base_segment($_) } @{$self->base_segments}]);
    
    return $contig;    
}

1;

