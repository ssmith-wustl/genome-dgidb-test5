package Bio::ContigUtilities::Read;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;
use Bio::ContigUtilities::Transform;

use Bio::ContigUtilities::SequenceItem;
use Bio::ContigUtilities::Sequence;

use base (qw(Bio::ContigUtilities::SequenceItem));

Bio::ContigUtilities::Read->mk_accessors(qw(align_clip_start align_clip_end qual_clip_start qual_clip_end info_count chromat_file phd_file time));

my $pkg = "Bio::ContigUtilities::Read";

=pod

=head1 NAME

Read - Class that manages a read's data.

=head1 DESCRIPTION

Bio::ContigUtilities::Read inherits from Bio::ContigUtilities::SequenceItem and has all it's functionality.  I also contains the getter/setters described below.

=head1 METHODS

=cut


=pod

=head1 new

$read = Bio::ContigUtilities::Read->new(children => \%children, tags => \@tags, position => $position, length => $length, ace_read => $ace_read, ace_read_position => $ace_read_position);
    
children - optional, a hash containing the items children, indexed by the child names.

tags - optional, an array of tags belonging to the item.

position - optional, the position of the item in the parent string.

length - optional, the length of the item in the parent item in padded base units.

ace_read - optional, will take a read hash as defined by GSC::IO::Assembly::Ace::Reader, and populate the fields of the read object.

ace_read_position - optional, will populate the read object with the data contained in an read_position.  This hash is produced by GSC::IO::Assembly::Ace::Reader.

=cut
sub new 
{
    croak("$pkg:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
#    my ($caller, $contig_hash, $reads, $contig_tags, $base_segments) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    
    my $self = $class->SUPER::new(%params);
        
    my $ace_read;
    my $ace_read_position;
    if(exists $params{ace_read})
    {
        $ace_read = $params{ace_read};
    }
    if(exists $params{ace_read_position})
    {
        $ace_read_position = $params{ace_read_position}; 
    }    
    
    
    $self->ace_read ($ace_read) if (defined ($ace_read));
    $self->ace_read_position ($ace_read_position) if (defined ($ace_read_position));
    
    return $self;
}

=pod

=head1 ace_read
    
$read->ace_read($ace_read)           

This is a getter/setter that takes or returns a copy of the read hash in the same format as the read hash that is produced by GSC::IO::Assembly::Ace::Reader/Writer.  This method helps to provide compatibility with the low-level Ace Reader/Writer.

=cut
sub ace_read
{
    my ($self, $ace_read) = @_;
    if(@_>1)
    {
        $self->sequence ( Bio::ContigUtilities::Sequence->new(sequence_state => "padded", padded_base_string => $ace_read->{sequence}));
        $self->name ( $ace_read->{name});
        $self->align_clip_start ($ace_read->{align_clip_start});
        $self->align_clip_end ($ace_read->{align_clip_end});
        $self->qual_clip_start ($ace_read->{qual_clip_start});
        $self->qual_clip_end ( $ace_read->{qual_clip_end});
        $self->info_count ($ace_read->{info_count}); 
        $self->chromat_file ( $ace_read->{description}{CHROMAT_FILE});
        $self->phd_file ($ace_read->{description}{PHD_FILE});
        $self->time ($ace_read->{description}{TIME});
    }                                         
    
    return { type => "read",
             name => $self->name,
             padded_base_count => $self->length,
             info_count => $self->info_count,
             tag_count => scalar(@{$self->tags}),
             sequence => $self->sequence->padded_base_string,
             qual_clip_start => $self->qual_clip_start,
             qual_clip_end => $self->qual_clip_end,
             align_clip_start => $self->align_clip_start,
             align_clip_end => $self->align_clip_end,
             description => {       
                CHROMAT_FILE => $self->chromat_file,
                PHD_FILE => $self->phd_file,
                TIME => $self->time }};
}

=pod

=head1 ace_read_position

$read->ace_read_position($ace_read_position)           

This is a getter/setter that takes or returns a copy of the read_position hash in the same format as the read_position hash that is produced by GSC::IO::Assembly::Ace::Reader/Writer.  This method helps to provide compatibility with the low-level Ace Reader/Writer.

=cut

sub ace_read_position
{
    my ($self, $ace_read_position) = @_;
    if(@_>1)
    {
        $self->position ($ace_read_position->{position});
        $self->complemented ($ace_read_position->{u_or_c} =~ /c/i or 0);
    }
    
    return { type => "read_position",
             read_name => $self->name,
             position => $self->position,
             u_or_c => ( $self->complemented ? "C" : "U" )
           };
}

=pod

=head1 base_count

$read->base_count           
 
This is returns the number of bases in unpadded units.   

=cut

sub base_count
{
    my ($self) = @_;

    return length $self->unpadded_base_string;
}

=pod

complemented
    $read->complemented           

    Getter/Setter for complemented boolean value.
=cut
sub complemented
{
    my ($self, $complemented) = @_;
    
    $self->sequence->complemented ($complemented) if (@_);
    
    return $self->sequence->complemented;
}

=pod

=head1 copy_tag

my $read_tag = $read->copy_tag($read_tag);           

Returns a copy of the read tag.

=cut

sub copy_tag
{
    my ($self, $read_tag) = @_;
    return { type => 'read_tag',
             tag_type => $read_tag->{tag_type},
             program => $read_tag->{program},
             start_pos => $read_tag->{start_pos},
             end_pos => $read_tag->{end_pos},
             date => $read_tag->{date}};
}

=pod

=head1 copy

my $read_copy = $read->copy($read);           

Returns a deep copy of the Read.

=cut

sub copy
{
    my ($self, $read) = @_;
    return Bio::ContigUtilities::Read->new(ace_read => $read->ace_read, 
                                                   ace_read_position => $read->ace_read_position,
                                                   tags => [map { $self->copy_tag($_)} @{$read->tags}]);
    
    
}
1;
