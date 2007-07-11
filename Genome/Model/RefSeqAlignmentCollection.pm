package Genome::Model::RefSeqAlignmentCollection;

use strict;
use warnings;

use IO::File;
use Convert::Binary::C;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw (LINKED_LIST_RECORD_SIZE INDEX_RECORD_SIZE MAX_READ_LENGTH);

BEGIN {
    use Config;
    unless ($Config{'use64bitint'}) {
        Carp::croak(__PACKAGE__ . " requires use64bitint to make use of the Q pack format");
    }
}

use constant INDEX_RECORD_SIZE => 8;  # The size of a quad?

use constant MAX_READ_LENGTH => 60;  # Only support reads this long
our $C_STRUCTS = Convert::Binary::C->new->parse(
      "struct linked_list_element{
            unsigned long long last_alignment_number;
            unsigned long long  read_number;
            double probability;
            unsigned char length;
            unsigned char  orientation;
            unsigned short number_of_alignments;
            unsigned char ref_and_mismatch_string[" . &MAX_READ_LENGTH . "];
      };
");

sub LINKED_LIST_RECORD_SIZE () {
    our $LINKED_LIST_RECORD_SIZE ||= $C_STRUCTS->sizeof('linked_list_element');
    return $LINKED_LIST_RECORD_SIZE;
}
    

=pod

=head1 NAME

Genome::Model::RefSeqAlignmentCollection - An API for packed aligment files

=head1 SYNOPSIS

  my $align = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => '/tmp/alignments_chr_1',
                                                            mode => O_RDWR | O_CREAT);
  $align->add_alignments_for_position(1, $alignment_record_list);
  $align->add_alignments_for_position(5, $another_alignment_record_list);
  
  my $alignment_list = $align->get_alignments_for_position(2);

=head2 CONSTRUCTOR

=over 4

=item $align = Genome::Model::RefSeqAlignmentCollection->new(%params);

The constructor returns a ref to a new RefSeqAlignmentCollection object, which encapsulates
access to both the index and data files.  The following parametes are accepted:

    alignments_file => Pathname to the .dat file containing alignment information
    index_file      => Pathname to the .ndx file containing offsets into the data
    file_prefix     => Can be provided in lieu of alignments_file and index_file.
                       It will look for file_prefix."_aln.dat" and file_prefix."_aln.ndx"
    mode            => The open mode for the files.  This is used as the 3rd argument
                       to the 3-arg open().  For existing files, you'll probably want
                       O_RDONLY; to create a new file, you'll probably want O_RDWR | O_CREAT.
                       O_LARGEFILE is automatically added to the mode.
    is_sorted       => Boolean flag to indicate whether the associated alignments data file
                       has been previously sorted.  During merge(), it will
                       use get_alignments_for_sorted_position() instead of
                       get_alignments_for_position().

Returns undef if there was an error.

=cut

sub new {
my($class,%params) = @_;

    # Normalize the params
    if ($params{'file_prefix'}) {
        $params{'index_file'} = $params{'file_prefix'} . '_aln.ndx';
        $params{'alignments_file'} = $params{'file_prefix'} . '_aln.dat';
        delete $params{'file_prefix'};
    }

    $params{'mode'} ||= O_RDONLY;   # File open mode defaults to read-only
    $params{'mode'} |= O_LARGEFILE; # on 64-bit systems, this should be a no-op

    my $self = bless { %params }, $class;

    $self->{'index_fh'} = IO::File->new($self->{'index_file'}, $self->{'mode'});
    unless ($self->{'index_fh'}) {
        Carp::carp("Can't open index file: $!") unless $self->{'index_fh'};
        return;
    }

    $self->{'alignments_fh'} = IO::File->new($self->{'alignments_file'}, $self->{'mode'});
    unless ($self->{'alignments_fh'}) {
        Carp::carp("Can't open alignments file: $!");
        return;
    }

    return $self;
}

=pod

=head2 Accessors

=item $align->index_file()

The pathname of the index file

=item $align->alignments_file()

The pathname of the alignments file

=item $align->index_fh()

An IO::File filehandle for the index file

=item $align->alignments_fh()

An IO::File filehandle for the alignment data

=cut

# read-only Accessors
foreach my $key ( qw ( index_file alignments_file index_fh alignments_fh) ) {
    my $string = "sub $key { return \$_[0]->{'$key'} }";
    eval $string;
}


=pod

=head2 Methods

=item $align->max_alignment_pos()

The maximum alignment position mentioned in the index file

=cut

sub max_alignment_pos {
my $self = shift;

    $self->index_fh->seek(0,2);
    my $size = int($self->index_fh->tell() / INDEX_RECORD_SIZE) - 1;

    return $size;
}

=pod

=item $new->merge($align1, <$align-n>);

Reads alignment data from one or more existing alignment files and merges them into
$new.  merge() is not a constructor; it must have already been created or opened with
new().  As a side effect, all new data written into $new from the other alignment objects
will be aggregated together by alignment position.

=cut


# Merging also implies aggregating records from the same position together (sorting)
sub merge {
my($new,@objs) = @_;

    my %get_sub_to_use;

    my $max_pos_seen = -1;
    foreach (@objs) {
        $get_sub_to_use{$_} = $_->{'is_sorted'} ? 'get_alignments_for_sorted_position' : 'get_alignments_for_position';
print "using $get_sub_to_use{$_} to get alignments data for ",$_->alignments_file,"\n";

        if ($_->max_alignment_pos > $max_pos_seen) {
            $max_pos_seen = $_->max_alignment_pos;
        }
    }

    for (my $pos = 1; $pos <= $max_pos_seen; $pos++) {   # The 0th position is a pad
        my $new_alignments = [];

        foreach my $obj ( @objs ) {
            my $get_sub = $get_sub_to_use{$obj};
            my $alignments = $obj->$get_sub($pos);

print "Got ",scalar @$alignments," for position $pos\n";
            push @$new_alignments, @$alignments;
        }

        $new->add_alignments_for_position($pos,$new_alignments);
    }


    return $new;
}

=pod

=item $align->flush()

Call flush() on the alignment and index file handles

=item $align->close()

Close the alignment and index file handles.  You will not be able to access data
from the object afterward.

=item $align->opened()

Returns true if both the alignment and index file handles are valid, opened handles.

=cut

sub flush {
my $self = shift;
    $self->alignments_fh->flush();
    $self->index_fh->flush();
}


sub close {
my $self = shift;
    $self->alignments_fh->close();
    $self->index_fh->close();
}

sub opened {
my $self = shift;
    return $self->alignments_fh->opened() && $self->index_fh->opened();
}


=pod

=item $alignment_listref = $align->get_alignments_for_position($pos)

Return a listref of alignment records for the given position.  Each record is a hashref
with the following keys: read_number, probability, length, orientation, number_of_alignments,
ref_and_mismatch_string, and last_alignment_number.  last_alignment_number is used internally
to manage the data structures inside the alignment data file.

=cut

sub get_alignments_for_position {
my($self,$pos) = @_;

    return unless ($self->opened);

    my $alignments = [];

    my $next_alignment_num = $self->_read_index_record_at_position($pos);

    while ($next_alignment_num) {
        my $alignment_struct = $self->get_alignment_node_for_alignment_num($next_alignment_num);
        push @$alignments, $alignment_struct;
        
        $next_alignment_num = $alignment_struct->{'last_alignment_number'};
    }
    return $alignments;
}

=pod

=item $alignment_listref = $align->get_alignments_for_sorted_position($pos)

Functions exactly like get_alignments_for_position, except that it assummes the
alignment data file has previously been sorted, and takes some shortcuts with
the data.  Do not call this on an unsorted data file or you'll likely get incorrect
data back.

=cut

sub get_alignments_for_sorted_position {
my($self,$pos) = @_;

    my $last_alignment_num = $self->_read_index_record_at_position($pos);
    return [] unless ($last_alignment_num);   # This position has no data

    my $first_alignment_num;
    if ($pos == 1) {
       $first_alignment_num = 1;
    } else {
        # find the first prior index position with data
        for ($pos--; !$first_alignment_num && $pos > 0; $pos--) {
            $first_alignment_num = $self->_read_index_record_at_position($pos);
        }
        if ($first_alignment_num) {
            # found one.  The data we're looking for starts at the next record
            $first_alignment_num++;
        } else {
            $first_alignment_num = 1;
        }
    }

    my $first_byte_offset = $first_alignment_num * LINKED_LIST_RECORD_SIZE;
    my $len = ($last_alignment_num - $first_alignment_num + 1) * LINKED_LIST_RECORD_SIZE;

    my $buf = '';
    my $totalread = 0;
    $self->alignments_fh->seek($first_byte_offset, 0);
    while ($totalread < $len) {
        my $read = $self->alignments_fh->read($buf, $len - $totalread, $totalread);
        unless ($read) {
            Carp::carp("Reading from alignments file at position " . $self->alignments_fh->tell . " failed: $!");
            return undef;
        }
        $totalread += $read;
    }

    my @alignments = $C_STRUCTS->unpack('linked_list_element', $buf);
    return \@alignments
}


=pod

=item $alignment_record = $align->get_alignment_node_for_alignment_num($offset)

Returns an individual alignment record out of the alignment data file at offset $offset.

=cut

# Should this be a private method?
sub get_alignment_node_for_alignment_num {
my($self,$alignment_num) = @_;
    return unless $alignment_num;

#    return unless ($self->opened);

#    my $fh = $self->alignments_fh;

#    local $/ = LINKED_LIST_RECORD_SIZE;

    $self->alignments_fh->seek($alignment_num * LINKED_LIST_RECORD_SIZE, 0);
#    my $buf = <$fh>;
    my $buf;
    unless ($self->alignments_fh->read($buf,LINKED_LIST_RECORD_SIZE)) {
        Carp::carp("reading from alignment data at record $alignment_num failed: $!");
        return undef;
    }
    my $struct = $C_STRUCTS->unpack('linked_list_element', $buf);

    return $struct;
}

=pod

=item $align->write_alignment_node_for_alignment_num($offset,$alignment_record)

Write the given alignment record at offset $offset in the alignment data file.
Please don't call this externally unless you know what you're doing, as it can
damage the data structure inside the file

=cut

# Should this be a private method?
sub write_alignment_node_for_alignment_num {
my($self,$alignment_num,$alignment) = @_;
    return unless ($self->opened);

    Carp::croak('Attempt to write to alignment record 0') unless $alignment_num;

    my $fh = $self->alignments_fh;

    $fh->seek($alignment_num * LINKED_LIST_RECORD_SIZE, 0);
    my $data = $C_STRUCTS->pack('linked_list_element', $alignment);
    $fh->print($data);
}
    
# This is used to read out data from the index file at the given position
sub _read_index_record_at_position {
my($self,$pos) = @_;
#    my $fh = $self->index_fh;

    $self->index_fh->seek($pos * INDEX_RECORD_SIZE,0);

#    local $/ = INDEX_RECORD_SIZE;

#    my $buf = <$fh>;
    my $buf;
    $self->index_fh->read($buf, INDEX_RECORD_SIZE);
    return 0 unless $buf;  # A read past the end will return nothing

    my $value = unpack("Q", $buf);

    return $value;
}

# This is used to write to the index file at the given position
sub _write_index_record_at_position {
my($self,$pos,$val) = @_;

    my $fh = $self->index_fh;

    $fh->seek($pos * INDEX_RECORD_SIZE,0);

    $val = pack("Q", $val);
    $fh->print($val);
}


=pod

=item $align->add_alignments_for_position($pos, $alignment_record_listref)

Add additional alignment records for alignment position $pos to the alignment
data file.

=cut

sub add_alignments_for_position {
my($self,$pos,$alignments) = @_;

    return unless ($self->opened);
    return unless ($alignments);

    my $last_alignment_num = $self->_read_index_record_at_position($pos);
    
    $self->alignments_fh->seek(0,2);  # Seek to the end
    my $first_record_to_write = int($self->alignments_fh->tell() / LINKED_LIST_RECORD_SIZE);
    $first_record_to_write ||= 1;  # don't write anything to the 0th record

    # Update the list pointers to all point to each other
    for (my $i = 0; $i < @$alignments; $i++) {
        my $alignment = $alignments->[$i];

        $alignment->{'last_alignment_number'} = $last_alignment_num;
        
        if ($i) {
            $last_alignment_num++;
        } else {
            $last_alignment_num = $first_record_to_write;
        }
    }

    # and write out the data
    $self->alignments_fh->seek($first_record_to_write * LINKED_LIST_RECORD_SIZE, 0);
    $self->alignments_fh->print(join('',
                                map { $C_STRUCTS->pack('linked_list_element',$_) }
                                @$alignments
                             ));

    $self->_write_index_record_at_position($pos,$last_alignment_num);
}

=pod

=back

=head1 File Format

The format for the index file is an array of quad ints.  The 0th position is not used currently
and should be considered reserved.  The index into this array corresponds to an alignment position
offset from the start of the chromosome.  Each data element is an offset (by record number,
not byte offset) into the data file pointing to an alignment record.  If there are no alignments
at this position, it contains null.

The data file is an array of C structures:

    struct linked_list_element{
            unsigned long long last_alignment_number;
            unsigned long long  read_number;
            double probability;
            unsigned char length;
            unsigned char  orientation;
            unsigned short number_of_alignments;
            unsigned char ref_and_mismatch_string[" . &MAX_READ_LENGTH . "];
      };

last_alignment_number is a pointer to the next element in the linked list, terminaing with null.  The 0th
position is not used in the alignment data file and should be considered reserved.

=cut

1;


