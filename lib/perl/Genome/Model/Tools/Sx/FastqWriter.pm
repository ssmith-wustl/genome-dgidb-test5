package Genome::Model::Tools::Sx::FastqWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::FastqWriter {
    is => 'Genome::Model::Tools::Sx::SeqWriter',
    has => [
        is_paired => { is => 'Boolean', is_optional => 1, },
        _fwd_fh => { is_optional => 1, },
        _rev_fh => { is_optional => 1, },
        _sing_fh => { is_optional => 1, },
        _max_files => { value => 3, },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;
    
    # 1 fh      => all to fh[0]
    # 1 fh prd  => only pairs to fh[0]
    # 2 fh      => f to fh[0] r to fh[1]
    # 2 fh prd  => f & r to fh[0] s to fh[1]
    # 3 fh      => f to fh[0] r to fh[1] s to fh[3]
    my @fhs = $self->_fhs;
    if ( @fhs == 1 ) {
        # f & r to fh0
        $self->_fwd_fh($fhs[0]);
        $self->_rev_fh($fhs[0]);
        if ( not $self->is_paired ) {
            # sing to fh0
            $self->_sing_fh($fhs[0]);
        }
    }
    elsif ( @fhs == 2 ) {
        $self->_fwd_fh($fhs[0]);
        if ( $self->is_paired ) {
            # f & r to fh0; s to fh1
            $self->_rev_fh($fhs[0]);
            $self->_sing_fh($fhs[1]);
        }
        else {
            # f to fh0; r to fh1; no s
            $self->_rev_fh($fhs[1]);
        }
    }
    else { 
        # f to fh0; r to fh1; s to fh2
        $self->_fwd_fh($fhs[0]);
        $self->_rev_fh($fhs[1]);
        $self->_sing_fh($fhs[2]);
    }

    return $self;
}

sub _write {
    my ($self, $seqs) = @_;

    if ( @$seqs == 1 ) {
        return 1 if not $self->_sing_fh;
        return $self->_print_seq_to_fh($self->_sing_fh, $seqs->[0]);
    }
    else {
        $self->_print_seq_to_fh($self->_fwd_fh, $seqs->[0]);
        $self->_print_seq_to_fh($self->_rev_fh, $seqs->[1]);
        return 1;
    }
}

sub _print_seq_to_fh {
    my ($self, $fh, $seq) = @_;

    $fh->print(
        join(
            "\n",
            '@'.$seq->{id}.( defined $seq->{desc} ? ' '.$seq->{desc} : '' ),
            $seq->{seq},
            '+',
            $seq->{qual},
        )."\n"
    );

    return 1;
}

1;

