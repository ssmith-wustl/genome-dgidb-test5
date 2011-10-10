package Genome::Data::Adaptor::Fasta;

use strict;
use warnings;

use Genome::Data::Sequence;
use Genome::Data::Adaptor;
use base 'Genome::Data::Adaptor';

sub sequence_number {
    my $self = shift;
    my $num = $self->{_seq_num};
    $num ||= 0;
    return $num;
}

sub current_sequence {
    my $self = shift;
    my $seq = $self->{_current_seq};
    return $seq;
}

sub parse_next_from_file {
    my $self = shift;
    my $fh = $self->_get_fh;
    my @lines = $self->_pop_cached_lines;
    while (my $line = $fh->getline) {
        chomp $line;
        if (@lines and $self->_is_valid_fasta_seq_name($line)) {
            $self->_push_line_to_cache($line);
            last;
        }
        else {
            push @lines, $line;
        }
    }

    my $seq_obj;
    if (@lines) {
        my $seq_name = shift @lines;
        unless ($self->_is_valid_fasta_seq_name($seq_name)) {
            Carp::confess "Could not determine sequence name for sequence number " . $self->sequence_number;
        }
        $seq_name =~ s/^>//;
        my $seq = join('', @lines);
        $seq_obj = Genome::Data::Sequence->create(
            sequence_name => $seq_name,
            sequence => $seq,
        );
        $self->_increment_sequence_number();
    }

    $self->_set_current_sequence($seq_obj);
    return $seq_obj;
}

sub write_to_file {
    my ($self, @sequences) = @_;
    for my $seq_obj (@sequences) {
        my ($self, $seq_obj) = @_;
        my $fh = $self->_get_fh;

        my $seq_name = $seq_obj->sequence_name;
        unless ($seq_name) {
            Carp::confess "Sequence has no name, cannot write to file " . $self->file;
        }
        $fh->print(">$seq_name\n");

        my $seq = $seq_obj->sequence;
        if ($seq) {
            for (my $i = 0; $i < (length $seq); $i += 80) {
                my $substr = substr($seq, $i, 80);
                $fh->print("$substr\n");
            }
        }

        $self->_set_current_sequence($seq_obj);
        $self->_increment_sequence_number;
    }

    return 1;
}

sub _set_current_sequence {
    my ($self, $seq) = @_;
    $self->{_current_seq} = $seq;
    return $seq;
}

sub _increment_sequence_number {
    my $self = shift;
    my $num = $self->sequence_number() + 1;
    $self->{_seq_num} = $num;
    return $self->{_seq_num};
}

sub _pop_cached_lines {
    my $self = shift;
    my @lines;
    if ($self->{_cached_lines}) {
        @lines = @{$self->{_cached_lines}};
    }
    delete $self->{_cached_lines};
    return @lines;
}

sub _push_line_to_cache {
    my ($self, $line) = @_;
    push @{$self->{_cached_lines}}, $line;
    return 1;
}

sub _is_valid_fasta_seq_name {
    my ($self, $line) = @_;
    if ($line =~ /^>/) {
        return 1;
    }
    return 0;
}

1;

