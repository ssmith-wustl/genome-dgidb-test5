package Genome::Model::Tools::Fastq::RandomSubset;

use strict;
use warnings;

use Math::Random;

class Genome::Model::Tools::Fastq::RandomSubset {
    is => 'Command',
    has => [
        input_fastq_file => {
            is => 'Text',
        },
        output_fastq_file => {
            is => 'Text',
        },
        subset_size => {
            is => 'Integer',
        },
    ],
    has_optional => [
        seed_phrase => { is => 'Text' },
        _index => { },
        _fh => { },
    ],
};


sub execute {
    my $self = shift;

    if ($self->seed_phrase) {
        random_set_seed_from_phrase($self->seed_phrase);
    }
    $self->_create_index;
    my $out = Genome::Utility::FileSystem->open_file_for_writing($self->output_fastq_file);
    my @index = @{$self->_index};
    my $n;
    if (scalar(@index) <= $self->subset_size) {
        $n = scalar(@index);
    } else {
        $n = $self->subset_size;
    }
    foreach my $i (random_uniform_integer($n, 0, scalar(@index))) {
        my $begin = $index[$i];
        my @fastq_lines = $self->get_fastq_lines($begin);
        for my $line (@fastq_lines) {
            print $out $line;
        }
    }
    $out->close;
    return 1;
}


sub _create_index {
    my $self = shift;
    my $begin = 0;
    my $fastq_file = $self->input_fastq_file;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($fastq_file);
    my @index;
    while (<$fh>) {
        if (/^@/) {
            # $begin is the position of the first character after the '@'
            my $begin = tell($fh) - length( $_ );
            push @index, $begin;
        }
    }
    $self->_fh($fh);
    $self->_index(\@index);
}

sub get_fastq_lines {
    my $self = shift;
    my $begin = shift;
    my $fh = $self->_fh;
    #set read pos
    $fh->seek($begin,0);
    my @fastq_lines;
    for (1 .. 4) {
        push @fastq_lines, $fh->getline;
    }
    return @fastq_lines;
}

