package Genome::Model::Tools::BioSamtools::ClusterCoverage;

use strict;
use warnings;

use Genome;
use Statistics::Descriptive;

my $DEFAULT_MINIMUM_DEPTHS = '1,5,10,15,20';
my $DEFAULT_OFFSET = 10_000_000;

class Genome::Model::Tools::BioSamtools::ClusterCoverage {
    is => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A path to a BAM format file of aligned capture reads',
        },
        minimum_depths => {
            is => 'Text',
            doc => 'A comma separated list of minimum depths to evaluate coverage',
            default_value => $DEFAULT_MINIMUM_DEPTHS,
            is_optional => 1,
        },
        offset => {
            is => 'Text',
            doc => 'The size(bp) of the sliding window offset.',
            default_value => $DEFAULT_OFFSET,
            is_optional => 1,
        },
        minimum_base_quality => {
            is => 'Text',
            doc => 'A minimum base quality to consider in coverage assesment.  THIS IS DEPRECATED FOR NOW.',
            is_deprecated => 1,
            is_optional => 1,
        },
        minimum_mapping_quality => {
            is => 'Text',
            doc => 'A minimum mapping quality to consider in coverage assesment.  THIS IS DEPRECATED FOR NOW.',
            is_deprecated => 1,
            is_optional => 1,
        },
        output_directory => {
            is => 'Text',
            doc => 'The output directory to generate cluster files per min depth.',
        },
        print_mean_coverage => {
            is => 'Boolean',
            doc => 'Calculate the mean depth across cluster.',
            default_value => 0,
        },
    ],
};

sub execute {
    my $self = shift;
    my $output_directory = $self->output_directory;
    unless (-d $output_directory) {
        unless (Genome::Sys->create_directory($output_directory)) {
            die('Failed to create output_directory: '. $output_directory);
        }
    }
    my $refcov_bam  = Genome::RefCov::Bam->create(bam_file => $self->bam_file );
    unless ($refcov_bam) {
        die('Failed to load bam file '. $self->bam_file);
    }
    my $bam  = $refcov_bam->bio_db_bam;
    my $index = $refcov_bam->bio_db_index;
    my $header = $bam->header();

    # Number of reference sequences
    my $targets = $header->n_targets();

    # The reference sequence names in an array ref with indexed positions
    my $target_names = $header->target_name();

    # at the low level API the seq_id/target_name is meaningless
    # cache the target_names in a hash by actual reference sequence name
    # then we can look up the target index on the fly
    my %target_name_index;
    my $i = 0;
    for my $target_name (@{ $target_names }) {
        $target_name_index{$target_name} = $i++;
    }

    # Make sure our index is not off
    unless ($targets == $i) {
        die 'Expected '. $targets .' targets but counted '. $i .' indices';
    }

    my $quality_coverage_callback = sub {
        my ($tid,$pos,$pileups,$data) = @_;
        die('I have not implemented or tested filtering by mapping or base quality');
        my ($start,$end,$coverage) = @$data;
        #Here the position $pos is always zero-based, but the end position has to be 1-based in the coverage function
        if ($pos < $start || $pos >= $end) { return; }
        my $index = $pos - $start;
        for my $pileup (@$pileups) {
            my $base_position = $pileup->qpos;
            my $alignment = $pileup->alignment;
            if (defined($self->minimum_mapping_quality)) {
                unless ($alignment->qual >= $self->minimum_mapping_quality) {
                    next;
                }
            }
            my @base_qualities = $alignment->qscore;
            my $quality = $base_qualities[$base_position];
            if ($quality >= $self->minimum_base_quality) {
                @$coverage[$index]++;
            }
        }
    };
    my $offset = $self->offset;
    my $genome_coverage_stats = Statistics::Descriptive::Sparse->new();
    my %min_depth_clusters_fhs;
    my @min_depths = split(',',$self->minimum_depths);
    for my $min_depth (@min_depths) {
        open (my $min_depth_clusters_fh, '>'. $output_directory .'/min_depth_'. $min_depth .'_clusters.bed');
        $min_depth_clusters_fhs{$min_depth} = $min_depth_clusters_fh;
    }
    for (my $tid = 0; $tid < $targets; $tid++) {
        my $chr = $header->target_name->[$tid];
        my $chr_length = $header->target_len->[$tid];
        my %min_depth_previous_clusters;
        for (my $start = 0; $start <= $chr_length; $start += $offset) {
            my $end = $start + $offset;
            if ($end > $chr_length) {
                $end = $chr_length;
            }
            
            # low-level API uses zero based coordinates
            # all regions should be zero based, but for some reason the correct length is never returned
            # the API must be expecting BED like inputs where the start is zero based and the end is 1-based
            # you can see in the docs for the low-level Bio::DB::BAM::Alignment class that start 'pos' is 0-based,but calend really returns 1-based
            my $coverage;
            if (defined($self->minimum_base_quality) || defined($self->minimum_mapping_quality)) {
                #Start with an empty array of zeros
                my @coverage = map { 0 } (1 .. $offset);
                $coverage = \@coverage;
                # the pileup callback will add each base gt or eq to the quality_filter to the index position in the array ref
                $index->pileup($bam,$tid,$start,$end,$quality_coverage_callback,[$start,$end,$coverage])
            } else {
                $coverage = $index->coverage( $bam, $tid, $start, $end);
                #print $start ."\t". $end ."\n";
            }
            for my $min_depth (@min_depths) {
                my @clusters = $self->cluster_coverage($coverage,$min_depth,$start);
                my $min_depth_clusters_fh = $min_depth_clusters_fhs{$min_depth};
                if (@clusters) {
                    if ($min_depth_previous_clusters{$min_depth}) {
                        my $last_cluster = $min_depth_previous_clusters{$min_depth}->[-1];
                        my $first_cluster = $clusters[0];
                        #print Data::Dumper::Dumper($last_cluster, $first_cluster);
                        if (($first_cluster->[0] == $last_cluster->[1])) {
                            #Blunt end clusters: merge
                            $last_cluster->[1] = $first_cluster->[1];
                            #Merge the stats
                            if ($self->print_mean_coverage) {
                                my @last_data = $last_cluster->[2]->get_data;
                                my @first_data = $first_cluster->[2]->get_data;
                                my @data;
                                push @data, @last_data;
                                push @data, @first_data;
                                my $new_stat = Statistics::Descriptive::Full->new();
                                $new_stat->add_data(@data);
                                $last_cluster->[2] = $new_stat;
                            }
                            shift(@clusters);
                        }
                        for my $cluster (@{$min_depth_previous_clusters{$min_depth}}) {
                            my $start = $cluster->[0];
                            my $end = $cluster->[1];
                            my $stat = $cluster->[2];
                            print $min_depth_clusters_fh $chr ."\t". $start ."\t". $end ."\t". $chr .':'. $start .'-'. $end;
                            if ($stat) {
                                print $min_depth_clusters_fh "\t". $stat->mean;
                            }
                            print $min_depth_clusters_fh "\n";
                        }
                    }
                    $min_depth_previous_clusters{$min_depth} = \@clusters;
                }
            }
        }
        for my $min_depth (keys %min_depth_previous_clusters) {
            my $min_depth_clusters_fh = $min_depth_clusters_fhs{$min_depth};
            for my $cluster (@{$min_depth_previous_clusters{$min_depth}}) {
                my $start = $cluster->[0];
                my $end = $cluster->[1];
                my $stat = $cluster->[2];
                print $min_depth_clusters_fh $chr ."\t". $start ."\t". $end ."\t". $chr .':'. $start .'-'. $end;
                if ($stat) {
                    print $min_depth_clusters_fh "\t". $stat->mean;
                }
                print $min_depth_clusters_fh "\n";
            }
            $min_depth_previous_clusters{$min_depth} = undef;
        }
    }
    for my $min_depth (keys %min_depth_clusters_fhs) {
        my $fh = $min_depth_clusters_fhs{$min_depth};
        $fh->close;
    }
    return 1;
}

sub cluster_coverage {
    my ($self, $coverage, $min_depth, $offset) = @_;
    my @clusters;
    # Populate the cluster data structure based on the coverage depth array.

    map {$_ = undef} my ($is_cluster, $start, $stop);
    my $last = scalar(@{ $coverage });
    my $stat;
    if ($self->print_mean_coverage) {
        $stat = Statistics::Descriptive::Full->new();
    }
    for (my $i = 0; $i < $last; $i++) {
        my $depth = $coverage->[$i];
        if ($depth >= $min_depth) {
            if ($is_cluster) {
                if ($stat) {
                    $stat->add_data($depth);
                }
                # continue extending existing cluster
                if ($i == ($last - 1)) {
                    # end of coverage array, so end cluster and finish
                    $stop = ($i + 1) + $offset;
                } else {
                    #reading through coverage
                    next;
                }
            } else {
                # start new cluster
                unless ($offset) {
                    $start = 1;
                }
                $start = $i + $offset;
                $is_cluster = 1;
                if ($self->print_mean_coverage) {
                    $stat = Statistics::Descriptive::Full->new();
                    $stat->add_data($depth);
                }
            }
        } else {
            if ($is_cluster) {
                # end of cluster, start of gap
                $stop = $i + $offset;
                $is_cluster = undef;
            } else {
                # reading through a gap
                next;
            }
        }
        # Update collection hash:
        if (defined($start) && defined($stop)) {
            push @clusters, [$start,$stop,$stat];
            $start = undef;
            $stop = undef;
        } elsif ($i == ($last - 1)) {
            # one base long cluster on end of coverage array
            push @clusters, [$start,$start,$stat];
            $start = undef;
            $stop = undef;
        }
    }
    return @clusters;
}


1;
