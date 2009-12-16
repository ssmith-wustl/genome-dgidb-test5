package Genome::Model::Tools::Fastq::RandomSubset;

use strict;
use warnings;

use Math::Random;

class Genome::Model::Tools::Fastq::RandomSubset {
    is => 'Command',
    has => [
        input_fastq_files => {
            is => 'Text',
            is_many => 1,
        },
        output_fastq_file => {
            is => 'Text',
        },
    ],
    has_optional => [
        seed_phrase => { is => 'Text' },
        reads => {
            is =>  'Integer',
        },
        base_pair => {
            is => 'Integer',
        },
        _index => { },
        _fhs => { },
        _shortest_seq => { },
    ],
};


sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self->reads || $self->base_pair) {
        die('Failed to define either reads or base_pair');
    }
    if ($self->reads && $self->base_pair) {
        die('Either reads or base_pair can be defined but not both');
    }
    return $self;
}

sub execute {
    my $self = shift;

    if ($self->seed_phrase) {
        random_set_seed_from_phrase($self->seed_phrase);
    }
    $self->_create_index;
    my $out = Genome::Utility::FileSystem->open_file_for_writing($self->output_fastq_file);
    my @index = @{$self->_index};
    my $n;
    if ($self->reads){ 
        if (scalar(@index) <= $self->reads) {
            die('The number of fastq entries '. scalar(@index) .' is less than subset size '. $self->reads);
            #$n = scalar(@index);
        } else {
            $n = $self->reads;
        }
    } elsif ($self->base_pair) {
        $n = int($self->base_pair / $self->_shortest_seq);
    }
    my @fhs = @{$self->_fhs};
    my $total_seq;
    foreach my $i (random_uniform_integer($n, 0, scalar(@index))) {
        my $index_array_ref = $index[$i];

        my $fh_id = $index_array_ref->[0];
        my $seq_length = $index_array_ref->[1];
        my $begin = $index_array_ref->[2];

        my $fh = $fhs[$fh_id];
        #set read pos
        $fh->seek($begin,0);
        my @fastq_lines;
        for (1 .. 4) {
            push @fastq_lines, $fh->getline;
        }
        for my $line (@fastq_lines) {
            print $out $line;
        }
        $total_seq += $seq_length;
        if ($self->base_pair && $total_seq >= $self->base_pair) {
            last;
        }
    }
    $out->close;
    return 1;
}


sub _create_index {
    my $self = shift;
    my @fastq_files = $self->input_fastq_files;
    my @fhs;
    my @index;
    for (my $file_id = 0; $file_id < scalar(@fastq_files); $file_id++) {
        my $fastq_file = $fastq_files[$file_id];
        my $fh = Genome::Utility::FileSystem->open_file_for_reading($fastq_file);
        my $seq_length;
        while (<$fh>) {
            if (/^@/) {
                # $begin is the position of the first character after the '@'
                my $begin = tell($fh) - length( $_ );
                # assumes equal sequence length within a fastq file
                unless ($seq_length) {
                    my $seq = $fh->getline;
                    chomp($seq);
                    $seq_length = length($seq);
                    if (defined($self->_shortest_seq)) {
                        if ($seq_length < $self->_shortest_seq) {
                            $self->_shortest_seq($seq_length);
                        }
                    } else { $self->_shortest_seq($seq_length); }
                }
                push @index, [$file_id,$seq_length,$begin];
            }
        }
        push @fhs, $fh;
    }
    $self->_fhs(\@fhs);
    $self->_index(\@index);
    return 1;
}

