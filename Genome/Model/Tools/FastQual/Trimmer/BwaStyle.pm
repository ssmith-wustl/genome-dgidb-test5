package Genome::Model::Tools::FastQual::Trimmer::BwaStyle;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::Trimmer::BwaStyle {
    is  => 'Genome::Model::Tools::FastQual::Trimmer',
    has_input => [
        trim_qual_level => {
            is  => 'Integer',
            doc => 'trim quality level',
            default => 10,
            is_optional => 1,
        },
    ],
};

sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS 
EOS
}


sub execute {
    my $self = shift;
        
    my $reader = $self->_open_reader
        or return;
    my $writer = $self->_open_writer
        or return;

    while ( my $seqs = $reader->next ) {
        $self->trim($seqs);
        $writer->write($seqs);
    }

    return 1;
}


sub trim {
    my ($self, $seqs) = @_;
    
    my ($qual_str, $qual_thresh) = $self->type eq 'sanger' ? ('#', 33) : ('B', 64);
    
    for my $seq ( @$seqs ) {
        my $seq_length = length $seq->{seq};

        my ($trim_seq, $trim_qual, $trimmed_length);
        my ($pos, $maxPos, $area, $maxArea) = ($seq_length, $seq_length, 0, 0);

        while ($pos > 0 and $area >= 0) {
            $area += $self->trim_qual_level - (ord(substr($seq->{qual}, $pos-1, 1)) - $qual_thresh);
            if ($area > $maxArea) {
                $maxArea = $area;
                $maxPos  = $pos;
            }
            $pos--;
        }

        if ($pos == 0) { 
            # scanned whole read and didn't integrate to zero?  replace with "empty" read ...
            $seq->{seq}  = 'N';
            $seq->{qual} = $qual_str;
            #($trim_seq, $trim_qual) = ('N', $qual_str);# scanned whole read and didn't integrate to zero?  replace with "empty" read ...
        }
        else {  # integrated to zero?  trim before position where area reached a maximum (~where string of qualities were still below 20 ...)
            $seq->{seq}  = substr($seq->{seq},  0, $maxPos);
            $seq->{qual} = substr($seq->{qual}, 0, $maxPos);
        }
        $trimmed_length = $seq_length - $maxPos;

    }

    return $seqs;
}

1;

#$HeadURL$
#$Id$
