package GenomeModel::ChromosomeAlignmentCollection;

use strict;
use warnings;

use IO::File;
use Convert::Binary::C;
use Exporter 'import';
our @EXPORT_OK = qw (END_TOKEN LINKED_LIST_RECORD_SIZE INDEX_RECORD_SIZE MAX_READ_LENGTH);

#use constant END_TOKEN => 2**64 - 1;  # Marks the end of a linked list
use constant END_TOKEN => 0xFFFFFFFFFFFFFFFF;  # Marks the end of a linked list

use constant LINKED_LIST_RECORD_SIZE => 8 + 8 + 8 + 1 + 1 + 62;  # Convert::Binary::C dosen't have a sizeof()

use constant INDEX_RECORD_SIZE => 8;  # The size of a quad?

use constant MAX_READ_LENGTH => 60;  # Only support reads this long
my $MAX_READ_LENGTH = &MAX_READ_LENGTH;
our $C_STRUCTS = Convert::Binary::C->new->parse(
      "struct linked_list_element{
            unsigned long long last_alignment_number;
            unsigned long long  read_number;
            double probability;
            unsigned char length;
            unsigned char  orientation;
            unsigned short number_of_alignments;
            unsigned char ref_and_mismatch_string[$MAX_READ_LENGTH];
      };
");


my $CHROMOSOME_LENGTHS = {
    1   =>      247249720,
    2   =>      242951150,
    3   =>      199501828,
    4   =>      191273064,
    5   =>      180857867,
    6   =>      170899993,
    7   =>      158821425,
    8   =>      146274827,
    9   =>      140273253,
    10  =>      135374738,
    11  =>      134452385,
    12  =>      132349535,
    13  =>      114142981,
    14  =>      106368586,
    15  =>      100338916,
    16  =>      88827255,
    17  =>      78774743,
    18  =>      76117154,
    19  =>      63811652,
    20  =>      62435965,
    21  =>      46944324,
    22  =>      49691433,
    X   =>      154913755,
    Y   =>      57772955,
    test=>      5,
};

# read-only Accessors
foreach my $key ( qw ( index_file alignments_file index_fh alignments_fh chr_name chr_len index_file_len) ) {
    my $string = "sub $key { return \$_[0]->{'$key'} }";
    eval $string;
}

sub new {
my($class,%params) = @_;

    # Normalize the params
    if ($params{'file_prefix'}) {
        $params{'index_file'} = $params{'file_prefix'} . '_aln.ndx';
        $params{'alignments_file'} = $params{'file_prefix'} . '_aln.dat';
        delete $params{'file_prefix'};
    }

    $params{'mode'} ||= 'r';   # File open mode defaults to 'r'

    my $self = bless { %params }, $class;

    my $chr_len = $self->{'chr_len'} || $CHROMOSOME_LENGTHS->{$params{'chr_name'}};
    unless($chr_len) {
        Carp::carp("Can't determine chromosome length");
    }
    $self->{'chromosome_length'} = $chr_len;

    $self->{'index_fh'} = IO::File->new($self->{'index_file'}, $self->{'mode'});
    unless ($self->{'index_fh'}) {
        Carp::carp("Can't open index file: $!") unless $self->{'index_fh'};
        return;
    }
    #$self->{'index_fh'}->input_record_separator(INDEX_RECORD_SIZE);  # This isn't supported per-fh
    $self->{'index_file_len'} = int((-s $self->{'index_file'}) / INDEX_RECORD_SIZE) - 1;

    $self->{'alignments_fh'} = IO::File->new($self->{'alignments_file'}, $self->{'mode'});
    unless ($self->{'alignments_fh'}) {
        Carp::carp("Can't open alignments file: $!");
        return;
    }
    #$self->{'alignments_fh'}->input_record_separator(LINKED_LIST_RECORD_SIZE);

    return $self;
}

# Merging also implies aggregating like elements together (sorting)
sub merge {
my($new,@objs) = @_;

    my $max_pos_seen = -1;
    foreach (@objs) {
        if ($_->index_file_len > $max_pos_seen) {
            $max_pos_seen = $_->index_file_len;
        }
    }

    for (my $pos = 1; $pos <= $max_pos_seen; $pos++) {   # The 0th position is a pad
        foreach my $obj ( @objs ) {
            my $alignments = $obj->get_alignments_for_position($pos);

            $new->add_alignments_for_position($pos,$alignments);
        }
    }

    return $new;
}


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

sub get_alignments_for_position {
my($self,$pos) = @_;

    return unless ($self->opened);

    my $alignments = [];

    my $next_alignment_num = $self->_read_index_record_at_position($pos);

    while ($next_alignment_num != END_TOKEN) {
        my $alignment_struct = $self->get_alignment_node_for_alignment_num($next_alignment_num);
        push @$alignments, $alignment_struct;
        
        $next_alignment_num = $alignment_struct->{'last_alignment_number'};
    }
    return $alignments;
}


sub get_alignment_node_for_alignment_num {
my($self,$alignment_num) = @_;
    return if $alignment_num == END_TOKEN;

    return unless ($self->opened);

    my $fh = $self->alignments_fh;

    local $/ = LINKED_LIST_RECORD_SIZE;

    $fh->seek($alignment_num * LINKED_LIST_RECORD_SIZE, 0);
    my $buf = <$fh>;
    my $struct = $C_STRUCTS->unpack('linked_list_element', $buf);

    return $struct;
}

sub write_alignment_node_for_alignment_num {
my($self,$alignment_num,$alignment) = @_;
    return unless ($self->opened);

    my $fh = $self->alignments_fh;

    $fh->seek($alignment_num * LINKED_LIST_RECORD_SIZE, 0);
    my $data = $C_STRUCTS->pack('linked_list_element', $alignment);
    $fh->print($data);
}
    


sub _read_index_record_at_position {
my($self,$pos) = @_;
    my $fh = $self->index_fh;

    if ($pos > $self->index_file_len) {
        return END_TOKEN;  # That's past the end, so there's no alignments at that pos
    }

    $fh->seek($pos * INDEX_RECORD_SIZE,0);

    local $/ = INDEX_RECORD_SIZE;

    my $buf = <$fh>;
    my $value = unpack("Q", $buf);

    return $value;
}

sub _write_index_record_at_position {
my($self,$pos,$val) = @_;

    my $fh = $self->index_fh;

    if ($pos > $self->index_file_len()) {
        $fh->seek(0,2);  # Seek to the current end of the file

        my $empty_records_to_write = $pos - $self->index_file_len - 1;
        $self->index_fh->print(pack("Q",END_TOKEN) x $empty_records_to_write);
        $self->{'index_file_len'} = $pos;
    } else {
        $fh->seek($pos * INDEX_RECORD_SIZE,0);
    }

    $val = pack("Q", $val);
    $fh->print($val);
}



sub add_alignments_for_position {
my($self,$pos,$alignments) = @_;

    return unless ($self->opened);

    my $last_alignment_num = $self->_read_index_record_at_position($pos);
    
    $self->alignments_fh->seek(0,2);  # Seek to the end

    for (my $i = 0; $i < @$alignments; $i++) {
        my $alignment = $alignments->[$i];

        $alignment->{'last_alignment_number'} = $last_alignment_num;
        
        my $data = $C_STRUCTS->pack('linked_list_element', $alignment);
        $self->alignments_fh->print($data);

        if ($i) {
            $last_alignment_num++;
        } else {
            $last_alignment_num = int($self->alignments_fh->tell() / LINKED_LIST_RECORD_SIZE) - 1;
        }
    }

    $self->_write_index_record_at_position($pos,$last_alignment_num);
}

1;


