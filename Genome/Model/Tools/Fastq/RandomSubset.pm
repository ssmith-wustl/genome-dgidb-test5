package Genome::Model::Tools::Fastq::RandomSubset;

use strict;
use warnings;

use Math::Random;

class Genome::Model::Tools::Fastq::RandomSubset {
    is => 'Command',
    has => [
        input_read_1_fastq_files => {
            is => 'Text',
            is_many => 1
        },
        output_read_1_fastq_file => {
            is => 'Text',
        },
        limit_type => {
            valid_values => ['reads','read_pairs','base_pair'],
        },
        limit_value => {
            is => 'Integer',
        },
        seed_phrase => {
            is => 'Text'
        },
    ],
    has_optional => [
        input_read_2_fastq_files => {
            is => 'Text',
            is_many => 1,
        },
        output_read_2_fastq_file => {
            is => 'Text',
        },
        _index => { },
        _read_1_fhs => { },
        _read_2_fhs => { },
        _shortest_seq => { },
        _max_read_per_end => { },
    ],
};

sub execute {
    my $self = shift;
    $self->_create_index;
    $self->_set_limits;
    $self->_generate_fastqs;
    return 1;
}

sub _create_index {
    my $self = shift;
    my @read_1_fastq_files = $self->input_read_1_fastq_files;
    my @read_2_fastq_files = $self->input_read_2_fastq_files;
    my @read_1_fhs;
    my @read_2_fhs;
    my @index;
    for (my $file_id = 0; $file_id < scalar(@read_1_fastq_files); $file_id++) {
        my $read_1_fastq_file = $read_1_fastq_files[$file_id];
        my $read_1_fh = Genome::Utility::FileSystem->open_file_for_reading($read_1_fastq_file);
        if (@read_2_fastq_files) {
            my $read_2_fastq_file = $read_2_fastq_files[$file_id];
            my $read_2_fh = Genome::Utility::FileSystem->open_file_for_reading($read_2_fastq_file);
            push @read_2_fhs, $read_2_fh;
        }
        while (my $header = $read_1_fh->getline) {
            if ($header =~ /^@/) {
                # $begin is the position of the first character after the '@'
                my $begin = tell($read_1_fh) - length( $header );
                my $seq = $read_1_fh->getline;
                chomp($seq);
                my $seq_length = length($seq);
                if (defined($self->_shortest_seq)) {
                    if ($seq_length < $self->_shortest_seq) {
                        $self->_shortest_seq($seq_length);
                    }
                } else { $self->_shortest_seq($seq_length); }
                push @index, $file_id .':'. $begin;
            }
        }
        push @read_1_fhs, $read_1_fh;
    }
    $self->_read_1_fhs(\@read_1_fhs);
    if (@read_2_fhs) {
        $self->_read_2_fhs(\@read_2_fhs);
    }
    $self->_index(\@index);
    return 1;
}

sub _set_limits {
    my $self = shift;
    
    my @index = @{$self->_index};
    my $factor = 1;
    if ($self->input_read_2_fastq_files) {
        $factor = 2;
    }
    if ($self->limit_type eq 'reads') {
        $self->_max_read_per_end(int($self->limit_value / $factor));
        if (scalar(@index) < $self->_max_read_per_end) {
            die('The number of fastq entries '. scalar(@index) .' is less than the number of reads required '. $self->_max_read_per_end);
        }
    } elsif ($self->limit_type eq 'read_pairs') {
        $self->_max_read_per_end($self->limit_value);
        if (scalar(@index) < $self->_max_read_per_end) {
            die('The number of fastq entries '. scalar(@index) .' is less than the number of reads required '. $self->_max_read_per_end);
        }
    } elsif ($self->limit_type eq 'base_pair') {
        my $per_file_limit = int($self->limit_value / $factor);
        $self->limit_value($per_file_limit);
        $self->_max_read_per_end(int( ($self->limit_value / $self->_shortest_seq)) + 1);
    }
    return 1;
}


sub _generate_fastqs {
    my $self = shift;
    $self->_generate_fastq_for_read_end(1);
    if ($self->input_read_2_fastq_files) {
        $self->_generate_fastq_for_read_end(2);
    }
    return 1;
}

sub _generate_fastq_for_read_end {
    my $self = shift;
    my $end = shift;
    
    unless ($end && ($end == 1 || $end == 2) ) {
        die('Invalid end '. $end .' passed to method _generate_read_end_fastq');
    }
    
    my $out_file_method = 'output_read_'. $end.'_fastq_file';
    my $out_file = $self->$out_file_method;
    my $out = Genome::Utility::FileSystem->open_file_for_writing($out_file);

    my @index = @{$self->_index};

    my $fhs_method = '_read_'. $end .'_fhs';
    my @fhs = @{$self->$fhs_method};
    
    my $total_seq;
    random_set_seed_from_phrase($self->seed_phrase);
    foreach my $i (random_uniform_integer($self->_max_read_per_end, 0, scalar(@index) - 1)) {
        my $index_string = $index[$i];
        my ($fh_id,$begin) = split(":",$index_string);

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
        if ($self->limit_type eq 'base_pair') {
            my $seq_length = length($fastq_lines[1]);
            $total_seq += $seq_length;
            if ($total_seq >= $self->limit_value) {
                last;
            }
        }
    }
    $out->close;
    if ($self->limit_type eq 'base_pair') {
        if ($total_seq < $self->limit_value) {
            die('There was only '. $total_seq .' base pair per end but expecting '. $self->limit_value);
        }
    }
    return 1;

}
