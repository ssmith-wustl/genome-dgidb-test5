package Genome::Model::Tools::FastQual::PhredWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::PhredWriter {
    is => 'Genome::Model::Tools::FastQual::SeqReaderWriter',
    has => [
        _fasta_io => { is_optional => 1, }, 
        _qual_io => { is_optional => 1, },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my @files = $self->files;
    if ( not @files ) {
        Carp::confess("No fasta/quality files given");
    }
    elsif ( @files > 2 ) {
        Carp::confess('Too many fasta/quality files given to write');
    }

    my $fasta_fh = eval{ Genome::Sys->open_file_for_appending($files[0]) };
    if ( not $fasta_fh ) {
        Carp::confess('Cannot open fasta file ('.$files[0].') for appending: '.$@);
    }
    $fasta_fh->autoflush(1);
    $self->_fasta_io($fasta_fh);
    
    if ( $files[1] ) {
        my $qual_fh = eval{ Genome::Sys->open_file_for_appending($files[1]); };
        if ( not $qual_fh ) {
            Carp::confess('Cannot open quality file ('.$files[1].') for appending: '.$@);
        }
        $self->_qual_io($qual_fh);
    }
    
    return $self;
}

sub write {
    my ($self, $seqs) = @_;

    Carp::confess('Need array of sequences to write') if not $seqs or ref $seqs ne 'ARRAY';

    for my $seq ( @$seqs ) { 
        $self->_write_seq($seq) or return;
        if ( $self->_qual_io ) {
            $self->_write_qual($seq) or return;
        }
    }

    return 1;
}

sub _write_seq {
    my ($self, $seq) = @_;

    my $header = '>'.$seq->{id};
    $header .= ' '.$seq->{desc} if defined $seq->{desc};
    $self->_fasta_io->print($header."\n");
    my $sequence = $seq->{seq};
    if ( defined $sequence && length($sequence) > 0 ) {
        $sequence =~ s/(.{1,60})/$1\n/g; # 60 bases per line
    } else {
        $sequence = "\n";
    }
    $self->_fasta_io->print($sequence);

    return 1;
}

sub _write_qual {
    my ($self, $seq) = @_;

    $self->_qual_io->print('>'.$seq->{id}."\n");
    my $max;
    my $last = @{$seq->{qual}} - 1;
    for ( my $count = 0; $count < $last; $count += 25 ) {
        $max = ( $count + 24 > $last )
        ? $last
        : $count + 24;
        $self->_qual_io->print(
            join(' ', @{$seq->{qual}}[$count..$max])."\n" 
        );
    }

    return 1;
}

1;

