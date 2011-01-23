package Genome::Model::Tools::BioSamtools::ClusterCoverage;

use strict;
use warnings;

use Genome;

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
    my $refcov_bam  = Genome::RefCov::Bam->new(bam_file => $self->bam_file );
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
            if (defined($self->mapping_quality_filter)) {
                unless ($alignment->qual >= $self->mapping_quality_filter) {
                    next;
                }
            }
            my @base_qualities = $alignment->qscore;
            my $quality = $base_qualities[$base_position];
            if ($quality >= $self->base_quality_filter) {
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
            if (defined($self->base_quality_filter) || defined($self->mapping_quality_filter)) {
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
                my @clusters = cluster_coverage($coverage,$min_depth,$start);
                my $min_depth_clusters_fh = $min_depth_clusters_fhs{$min_depth};
                if (@clusters) {
                    if ($min_depth_previous_clusters{$min_depth}) {
                        my $last_cluster = $min_depth_previous_clusters{$min_depth}->[-1];
                        my $first_cluster = $clusters[0];
                        #print Data::Dumper::Dumper($last_cluster, $first_cluster);
                        if (($first_cluster->[0] == $last_cluster->[1])) {
                            #Blunt end clusters: merge
                            $last_cluster->[1] = $first_cluster->[1];
                            shift(@clusters);
                        }
                        for my $cluster (@{$min_depth_previous_clusters{$min_depth}}) {
                            print $min_depth_clusters_fh $chr ."\t". $cluster->[0] ."\t". $cluster->[1] ."\n";
                        }
                    }
                    $min_depth_previous_clusters{$min_depth} = \@clusters;
                }
            }
        }
        for my $min_depth (keys %min_depth_previous_clusters) {
            my $min_depth_clusters_fh = $min_depth_clusters_fhs{$min_depth};
            for my $cluster (@{$min_depth_previous_clusters{$min_depth}}) {
                print $min_depth_clusters_fh $chr ."\t". $cluster->[0] ."\t". $cluster->[1] ."\n";
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
    my ($coverage, $min_depth, $offset) = @_;
    my @clusters;
    # Populate the cluster data structure based on the coverage depth array.

    map {$_ = undef} my ($is_cluster, $start, $stop);
    my $last = scalar(@{ $coverage });
    for (my $i = 0; $i < $last; $i++) {
        my $depth = $coverage->[$i];
        if ($depth >= $min_depth) {
            if ($is_cluster) {
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
            push @clusters, [$start,$stop];
            $start = undef;
            $stop = undef;
        } elsif ($i == ($last - 1)) {
            # one base long cluster on end of coverage array
            push @clusters, [$start,$start];
            $start = undef;
            $stop = undef;
        }
    }
    return @clusters;
}


1;
