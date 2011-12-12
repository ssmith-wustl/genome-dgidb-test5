package Genome::Model::Tools::Sx::Metrics::Assembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::Metrics::Assembly {
    is => 'Genome::Model::Tools::Sx::Metrics::Base',
    has => [
        major_contig_threshold => {
            is => 'Number',
            default_value => 300,
            doc => ' one base threshold.',
        },
        tier_one => {
            is => 'Number',
            is_optional => 1,
            doc => 'Tier one base threshold.',
        },
        tier_two => {
            is => 'Number',
            is_optional => 1,
            doc => 'Tier two base threshold.',
        },
        _metrics => {
            is => 'Hash',
            is_optional => 1,
            default_value => {
                supercontigs_length => 0,
                supercontigs_count => 0,
                contigs_length => 0,
                contigs_count => 0,
                reads_length => 0,
                reads_count => 0,
            },
        },
        supercontigs => {
            is => 'Hash',
            is_optional => 1,
            default_value => {},
        },
        contigs => {
            is => 'Hash',
            is_optional => 1,
            default_value => {}, 
        },
        _are_metrics_calculated => {
            is => 'Boolean',
            default_value => 0,
        },
    ],
};

class Sx::Metrics::Assembly {
    has => [
        map(
            { $_ => { is => 'Number' }, } 
            (qw/
                tier_one tier_two major_contig_threshold
                contigs_average_length
                contigs_count
                contigs_length
                contigs_length_q20
                contigs_length_q20_percent
                contigs_major_average_length
                contigs_major_count
                contigs_major_length
                contigs_major_length_q20
                contigs_major_length_q20_percent
                contigs_major_n50_count
                contigs_major_n50_length
                contigs_maximum_length
                contigs_n50_count
                contigs_n50_length
                contigs_t1_count
                contigs_t1_length
                contigs_t1_average_length
                contigs_t1_length_q20
                contigs_t1_length_q20_percent
                contigs_t1_maximum_length
                contigs_t1_n50_count
                contigs_t1_n50_length
                contigs_t1_n50_not_reached
                contigs_t2_count
                contigs_t2_length
                contigs_t2_average_length
                contigs_t2_length_q20
                contigs_t2_length_q20_percent
                contigs_t2_maximum_length
                contigs_t2_n50_count
                contigs_t2_n50_length
                contigs_t2_n50_not_reached
                contigs_t3_count
                contigs_t3_length
                contigs_t3_average_length
                contigs_t3_length_q20
                contigs_t3_length_q20_percent
                contigs_t3_maximum_length
                contigs_t3_n50_count
                contigs_t3_n50_length
                contigs_t3_n50_not_reached
                reads_average_length
                reads_chaff_rate
                reads_count
                reads_length
                reads_length_q20
                reads_length_q20_per_read
                reads_length_q20_redundancy
                reads_placed
                reads_placed_duplicate
                reads_placed_in_scaffolds
                reads_placed_unique
                reads_unplaced
                scaffolds_1M
                scaffolds_250K_1M
                scaffolds_100K_250K
                scaffolds_10K_100K
                scaffolds_5K_10K
                scaffolds_2K_5K
                scaffolds_0K_2K
                supercontigs_average_length
                supercontigs_count
                supercontigs_length
                supercontigs_length_q20
                supercontigs_length_q20_percent
                supercontigs_major_average_length
                supercontigs_major_count
                supercontigs_major_length
                supercontigs_major_length_q20
                supercontigs_major_length_q20_percent
                supercontigs_major_n50_count
                supercontigs_major_n50_length
                supercontigs_maximum_length
                supercontigs_n50_count
                supercontigs_n50_length
                supercontigs_t1_count
                supercontigs_t1_length
                supercontigs_t1_average_length
                supercontigs_t1_length_q20
                supercontigs_t1_length_q20_percent
                supercontigs_t1_maximum_length
                supercontigs_t1_n50_count
                supercontigs_t1_n50_length
                supercontigs_t1_n50_not_reached
                supercontigs_t2_count
                supercontigs_t2_length
                supercontigs_t2_average_length
                supercontigs_t2_length_q20
                supercontigs_t2_length_q20_percent
                supercontigs_t2_maximum_length
                supercontigs_t2_n50_count
                supercontigs_t2_n50_length
                supercontigs_t2_n50_not_reached
                supercontigs_t3_count
                supercontigs_t3_length
                supercontigs_t3_average_length
                supercontigs_t3_length_q20
                supercontigs_t3_length_q20_percent
                supercontigs_t3_maximum_length
                supercontigs_t3_n50_count
                supercontigs_t3_n50_length
                supercontigs_t3_n50_not_reached
                /)
        ),
    ],
};

sub add_contigs_file {
    my $self = shift;
    return $self->_add_file('contig', @_);
}

sub add_reads_file {
    my $self = shift;
    return $self->_add_file('read', @_);
}

sub _add_file {
    my ($self, $type, $file_config) = @_;

    Carp::confess('No type to add file!') if not $type;
    Carp::confess("No file config to add $type file!") if not $file_config;

    my $reader = Genome::Model::Tools::Sx::Reader->create(config => [ $file_config ]);
    if ( not $reader ) {
        $self->error_message('Failed to open read file: '.$file_config);
        return;
    }

    my $method = 'add_'.$type;
    while ( my $seqs = $reader->read ) {
        for my $seq ( @$seqs ) {
            $self->$method($seq);
        }
    }

    return 1;
}

sub add_contig {
    my ($self, $contig) = @_;

    my $id = $contig->{id};
    $id =~ s/^contig//i;
    my ($supercontig_number, $contig_number) = split(/\./, $id);
    $contig_number = 0 if not defined $contig_number;
    $contig_number = $supercontig_number.'.'.$contig_number;

    $self->_metrics->{supercontigs_count}++ if not exists $self->supercontigs->{$supercontig_number};
    $self->_metrics->{supercontigs_length} += length $contig->{seq};
    $self->supercontigs->{$supercontig_number} += length $contig->{seq};

    $self->_metrics->{contigs_count}++;
    $self->_metrics->{contigs_length} += length $contig->{seq};
    $self->contigs->{$contig_number} = length $contig->{seq};

    return 1;
}

sub add_read {
    my ($self, $read) = @_;

    $self->_metrics->{reads_count}++;
    $self->_metrics->{reads_length} += length $read->{seq};

    return 1;
}

sub calculate_metrics {
    my $self = shift;

    my $main_metrics = $self->_metrics;

    # Attrs
    $main_metrics->{tier_one} = $self->tier_one;
    $main_metrics->{tier_two} = $self->tier_one + $self->tier_two;
    $main_metrics->{major_contig_threshold} = $self->major_contig_threshold;

    # Reads
    $main_metrics->{reads_average_length} = int($main_metrics->{reads_length} / $main_metrics->{reads_count});
    $main_metrics->{reads_length_q20} = 'NA';
    $main_metrics->{reads_length_q20_per_read} = 'NA';
    $main_metrics->{reads_placed} = 'NA';
    $main_metrics->{reads_placed_in_scaffolds} = 'NA';
    $main_metrics->{reads_placed_unique} = 'NA';
    $main_metrics->{reads_placed_duplicate} = 'NA';
    $main_metrics->{reads_unplaced} = 'NA';
    $main_metrics->{reads_chaff_rate} = 'NA';
    $main_metrics->{reads_length_q20_redundancy} = 'NA';

    my $t1 = $self->tier_one;
    my $t2 = $self->tier_two;
    my $q20_metrics = {};
    my $total_contig_length = $self->_metrics->{contigs_length};
    for my $type (qw/ contigs supercontigs /) {
        my $metrics = $self->$type;

        #TYPE IS CONTIG OR SUPERCONTIG
        my $major_contig_length = $self->major_contig_threshold;
        my $t3 = $total_contig_length - ($t1 + $t2);
        #TOTAL CONTIG VARIABLES
        my $total_contig_number = 0;    my $cumulative_length = 0;
        my $maximum_contig_length = 0;  my $major_contig_number = 0;
        my $major_contig_bases = 0;     my $major_contig_q20_bases = 0;
        my $n50_contig_number = 0;      my $n50_contig_length = 0;
        my $not_reached_n50 = 1;        my $total_q20_bases = 0;
        #TIER 1 VARIABLES
        my $total_t1_bases = 0;         my $total_t1_q20_bases = 0;
        my $t1_n50_contig_number = 0;   my $t1_n50_contig_length = 0;
        my $t1_not_reached_n50 = 1;     my $t1_max_length = 0;
        my $t1_count = 0;
        #TIER 2 VARIABLES
        my $total_t2_bases = 0;         my $total_t2_q20_bases = 0;
        my $t2_n50_contig_number = 0;   my $t2_n50_contig_length = 0;
        my $t2_not_reached_n50 = 1;     my $t2_max_length = 0;
        my $t2_count = 0;
        #TIER 3 VARIABLES
        my $total_t3_bases = 0;         my $total_t3_q20_bases = 0;
        my $t3_n50_contig_number = 0;   my $t3_n50_contig_length = 0;
        my $t3_not_reached_n50 = 1;     my $t3_max_length = 0;
        my $t3_count = 0;
        #ASSESS CONTIG / SUPERCONTIG SIZE VARIABLES
        my $larger_than_1M = 0;         my $larger_than_250K = 0;
        my $larger_than_100K = 0;       my $larger_than_10K = 0;
        my $larger_than_5K = 0;         my $larger_than_2K = 0;
        my $larger_than_0K = 0;

        foreach my $c (sort {$metrics->{$b} <=> $metrics->{$a}} keys %{$metrics}) {
            $total_contig_number++;
            $total_q20_bases += $q20_metrics->{$c}->{q20_bases} if exists $q20_metrics->{$c};
            $cumulative_length += $metrics->{$c};

            if ($metrics->{$c} > $major_contig_length) {
                $major_contig_bases += $metrics->{$c};
                $major_contig_q20_bases += $q20_metrics->{$c}->{q20_bases}if exists $q20_metrics->{$c};
                $major_contig_number++;
            }
            if ($not_reached_n50) {
                $n50_contig_number++;
                if ($cumulative_length >= ($total_contig_length * 0.50)) {
                    $n50_contig_length = $metrics->{$c};
                    $not_reached_n50 = 0;
                }
            }
            if ($metrics->{$c} > $maximum_contig_length) {
                $maximum_contig_length = $metrics->{$c};
            }
            #TIER 1
            if ($total_t1_bases < $t1) {
                $total_t1_bases += $metrics->{$c};
                $total_t1_q20_bases += $q20_metrics->{$c}->{q20_bases} if exists $q20_metrics->{$c};
                if ($t1_not_reached_n50) {
                    $t1_n50_contig_number++;
                    if ($cumulative_length >= ($t1 * 0.50)) {
                        $t1_n50_contig_length = $metrics->{$c};
                        $t1_not_reached_n50 = 0;
                    }
                }
                $t1_count++;
                if ($t1_max_length == 0) {
                    $t1_max_length = $metrics->{$c}
                }
            }
            #TIER 2
            elsif ($total_t2_bases < $t2) {
                $total_t2_bases += $metrics->{$c};
                $total_t2_q20_bases += $q20_metrics->{$c}->{q20_bases} if exists $q20_metrics->{$c};
                if ($t2_not_reached_n50) {
                    $t2_n50_contig_number++;
                    if ($cumulative_length >= ($t2 * 0.50)) {
                        $t2_n50_contig_length = $metrics->{$c};
                        $t2_not_reached_n50 = 0;
                    }
                }
                $t2_count++;
                if ($t2_max_length == 0) {
                    $t2_max_length = $metrics->{$c}
                }
            }
            #TIER 3
            else {
                $total_t3_bases += $metrics->{$c};
                $total_t3_q20_bases += $q20_metrics->{$c}->{q20_bases} if exists $q20_metrics->{$c};
                if ($t3_not_reached_n50) {
                    $t3_n50_contig_number++;
                    if ($cumulative_length >= ($t3 * 0.50)) {
                        $t3_n50_contig_length = $metrics->{$c};
                        $t3_not_reached_n50 = 0;
                    }
                }
                $t3_count++;
                if ($t3_max_length == 0) {
                    $t3_max_length = $metrics->{$c}
                }
            }

            #FOR SUPERCONTIGS CONTIGUITY METRICS .. calculated number of contigs > 1M, 250K, 100-250K etc
            if ($metrics->{$c} > 1000000) {
                $larger_than_1M++;
            }
            elsif ($metrics->{$c} > 250000) {
                $larger_than_250K++;
            }
            elsif ($metrics->{$c} > 100000) {
                $larger_than_100K++;
            }
            elsif ($metrics->{$c} > 10000) {
                $larger_than_10K++;
            }
            elsif ($metrics->{$c} > 5000) {
                $larger_than_5K++;
            }
            elsif ($metrics->{$c} > 2000) {
                $larger_than_2K++;
            }
            else {
                $larger_than_0K++;
            }
        }

        #NEED TO ITERATE THROUGH metrics HASH AGAGIN FOR N50 SPECIFIC STATS
        #TODO - This can be avoided by calculating and storing total major-contigs-bases
        #in metrics hash
        my $n50_cumulative_length = 0; my $n50_major_contig_number = 0;
        my $not_reached_major_n50 = 1; my $n50_major_contig_length = 0;
        foreach my $c (sort {$metrics->{$b} <=> $metrics->{$a}} keys %$metrics) {
            next unless $metrics->{$c} > $major_contig_length;
            $n50_cumulative_length += $metrics->{$c};
            if ($not_reached_major_n50) {
                $n50_major_contig_number++;
                if ($n50_cumulative_length >= $major_contig_bases * 0.50) {
                    $not_reached_major_n50 = 0;
                    $n50_major_contig_length = $metrics->{$c};
                }
            }
        }

        my $q20_ratio = 0;                  my $t1_q20_ratio = 0;
        my $t2_q20_ratio = 0;               my $t3_q20_ratio = 0;
        my $major_contig_q20_ratio = 0;

        $total_t1_q20_bases = 'NA';
        $total_t2_q20_bases = 'NA';
        $total_t3_q20_bases = 'NA';
        $t1_q20_ratio = 'NA';
        $t2_q20_ratio = 'NA';
        $t3_q20_ratio = 'NA';

        $main_metrics->{$type.'_length_q20'} = 'NA';
        $main_metrics->{$type.'_length_q20_percent'} = 'NA';
        $main_metrics->{$type.'_average_length'} = int ($cumulative_length / $total_contig_number + 0.50);
        $main_metrics->{$type.'_maximum_length'} = $maximum_contig_length;
        $main_metrics->{$type.'_n50_length'} = $n50_contig_length;
        $main_metrics->{$type.'_n50_count'} = $n50_contig_number;
        $main_metrics->{$type.'_major_count'} = $major_contig_number;
        $main_metrics->{$type.'_major_length'} = $major_contig_bases;
        $main_metrics->{$type.'_major_average_length'} = ($major_contig_number > 0) 
        ?  int ($major_contig_bases / $major_contig_number + 0.50) 
        : 0;
        $main_metrics->{$type.'_major_length_q20'} = 'NA';
        $main_metrics->{$type.'_major_length_q20_percent'} = 'NA';
        $main_metrics->{$type.'_major_n50_length'} = $n50_contig_length;
        $main_metrics->{$type.'_major_n50_count'} = $n50_major_contig_number;

        $main_metrics->{$type.'_t1_length'} = $total_t1_bases;
        $main_metrics->{$type.'_t1_count'} = $t1_count;
        $main_metrics->{$type.'_t1_average_length'} = ($t1_count > 0) ? int ($total_t1_bases/$t1_count + 0.5) : 0;
        $main_metrics->{$type.'_t1_length_q20'} = $total_t1_q20_bases;
        $main_metrics->{$type.'_t1_length_q20_percent'} = $t1_q20_ratio;
        $main_metrics->{$type.'_t1_n50_count'} = $t1_n50_contig_number;
        $main_metrics->{$type.'_t1_n50_length'} = $t1_n50_contig_length;
        $main_metrics->{$type.'_t1_n50_not_reached'} = $t1_not_reached_n50; 
        $main_metrics->{$type.'_t1_maximum_length'} = $t1_max_length;

        $main_metrics->{$type.'_t2_length'} = $total_t2_bases;
        $main_metrics->{$type.'_t2_count'} = $t2_count;
        $main_metrics->{$type.'_t2_average_length'} = ($t2_count > 0) ? int ($total_t2_bases/$t2_count + 0.5) : 0;
        $main_metrics->{$type.'_t2_length_q20'} = $total_t1_q20_bases;
        $main_metrics->{$type.'_t2_length_q20_percent'} = $t1_q20_ratio;
        $main_metrics->{$type.'_t2_n50_count'} = $t2_n50_contig_number;
        $main_metrics->{$type.'_t2_n50_length'} = $t2_n50_contig_length;
        $main_metrics->{$type.'_t2_n50_not_reached'} = $t2_not_reached_n50; 
        $main_metrics->{$type.'_t2_maximum_length'} = $t2_max_length;

        $main_metrics->{$type.'_t3_length'} = $total_t3_bases;
        $main_metrics->{$type.'_t3_count'} = $t3_count;
        $main_metrics->{$type.'_t3_average_length'} = ($t3_count > 0) ? int ($total_t3_bases/$t3_count + 0.5) : 0;
        $main_metrics->{$type.'_t3_length_q20'} = $total_t1_q20_bases;
        $main_metrics->{$type.'_t3_length_q20_percent'} = $t1_q20_ratio;
        $main_metrics->{$type.'_t3_n50_count'} = $t3_n50_contig_number;
        $main_metrics->{$type.'_t3_n50_length'} = $t3_n50_contig_length;
        $main_metrics->{$type.'_t3_n50_not_reached'} = $t3_not_reached_n50; 
        $main_metrics->{$type.'_t3_maximum_length'} = $t3_max_length;

        if ($type eq 'supercontigs') {
            $main_metrics->{'scaffolds_1M'} = $larger_than_1M;
            $main_metrics->{'scaffolds_250K_1M'} = $larger_than_250K;
            $main_metrics->{'scaffolds_100K_250K'} = $larger_than_100K;
            $main_metrics->{'scaffolds_10K_100K'} = $larger_than_10K;
            $main_metrics->{'scaffolds_5K_10K'} = $larger_than_5K;
            $main_metrics->{'scaffolds_2K_5K'} = $larger_than_2K;
            $main_metrics->{'scaffolds_0K_2K'} = $larger_than_0K;
        }
    }

    return $self->_metrics;
}

1;

