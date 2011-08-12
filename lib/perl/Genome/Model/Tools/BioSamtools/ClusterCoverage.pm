package Genome::Model::Tools::BioSamtools::ClusterCoverage;

use strict;
use warnings;

use Genome;
use Statistics::Descriptive;
use PDL;
use PDL::NiceSlice;

my $DEFAULT_MINIMUM_DEPTH = '1';
my $DEFAULT_OFFSET = 50_000_000;

class Genome::Model::Tools::BioSamtools::ClusterCoverage {
    is => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A path to a BAM format file of aligned capture reads',
        },
        minimum_depth => {
            is => 'Text',
            doc => 'A comma separated list of minimum depths to evaluate coverage',
            default_value => $DEFAULT_MINIMUM_DEPTH,
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
        bed_file => {
            is => 'Text',
            doc => 'The output BED format file of clusters.',
        },
        stats_file => {
            is => 'Text',
            doc => 'Calculate statistics across clusters and print to file.',
            is_optional => 1,
        },
    ],
};

sub execute {
    my $self = shift;
    
    my $bed_fh = Genome::Sys->open_file_for_writing($self->bed_file);
    unless ($bed_fh) {
        die('Failed to open file for writing: '. $self->bed_file);
    }
    my $stats_fh;
    if ($self->stats_file) {
        $stats_fh = Genome::Sys->open_file_for_writing($self->stats_file);
        unless ($stats_fh) {
            die('Failed to open file for writing: '. $self->stats_file);
        }
        print $stats_fh "name\tmean\tprms\tmed\tmin\tmax\tadev\trms\n";
    }
    my $refcov_bam  = Genome::Model::Tools::RefCov::Bam->create(bam_file => $self->bam_file );
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
    my $min_depth = $self->minimum_depth;
    for (my $tid = 0; $tid < $targets; $tid++) {
        my @previous_clusters;
        my $chr = $header->target_name->[$tid];
        #print 'Starting: '. $chr ."\n";
        my $chr_length = $header->target_len->[$tid];
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
            #my @clusters = $self->cluster_coverage($coverage,$min_depth,$start);
            #print $chr ."\t". $start ."\t". scalar(@{$coverage}) ."\n";
            my @clusters = $self->pdl_clusters($coverage,$min_depth,$start);
            if (@clusters) {
                if (@previous_clusters) {
                    my $last_cluster = $previous_clusters[-1];
                    my $first_cluster = $clusters[0];
                    #print Data::Dumper::Dumper($last_cluster, $first_cluster);
                    if (($first_cluster->[0] == $last_cluster->[1])) {
                        #Blunt end clusters: merge
                        $last_cluster->[1] = $first_cluster->[1];
                        #Merge the stats
                        if ($self->print_mean_coverage) {
                            my $last_pdl = $last_cluster->[2];
                            my $first_pdl = $first_cluster->[2];
                            $last_pdl->append($first_pdl);
                        }
                        shift(@clusters);
                    }
                    for my $cluster (@previous_clusters) {
                        my $start = $cluster->[0];
                        my $end = $cluster->[1];
                        my $pdl = $cluster->[2];
                        my $name = $chr .':'. $start .'-'. $end;
                        print $bed_fh $chr ."\t". $start ."\t". $end ."\t". $name ."\n";
                        if ($stats_fh) {
                            if (defined($pdl)) {
                                my ($mean,$prms,$med,$min,$max,$adev,$rms) = $pdl->stats;
                                print $stats_fh $name ."\t". $mean ."\t". $prms ."\t". $med ."\t". $min ."\t". $max ."\t". $adev ."\t". $rms ."\n";
                            } else {
                                print $stats_fh $name ."\t0\t0\t0\t0\t0\t0\t0\n";
                            }
                        }
                    }
                }
                @previous_clusters = @clusters;
            }
        }
        for my $cluster (@previous_clusters) {
            my $start = $cluster->[0];
            my $end = $cluster->[1];
            my $pdl = $cluster->[2];
            print $bed_fh $chr ."\t". $start ."\t". $end ."\t". $chr .':'. $start .'-'. $end;
            if (defined($pdl)) {
                my ($mean,$prms,$med,$min,$max,$adev,$rms) = $pdl->stats;
            print $bed_fh "\t". $mean;
            }
            print $bed_fh "\n";
        }
        #print 'Finished: '. $chr ."\n";
    }
    $bed_fh->close;
    return 1;
}

sub cluster_coverage {
    my ($self, $coverage, $min_depth, $offset) = @_;

    my @clusters;
    # Populate the cluster data structure based on the coverage depth array.
    map {$_ = undef} my ($is_cluster, $start, $stop);

    my $last = scalar(@{ $coverage });
    unless ($last) { return };

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

sub pdl_clusters {
    my $self = shift;

    my $coverage = shift;
    my $min_depth = shift;
    my $offset = shift;

    unless (scalar(@{$coverage})) { return };

    my $chr_pdl = pdl $coverage;
    my ($quantity,$value) = rle($chr_pdl >= $min_depth);
    my ($padded_quantity,$padded_value) = $quantity->where($value,$quantity!=0);
    my $padded_quantity_cumsum = $padded_quantity->cumusumover;

    my ($chr_gt_min_depth_idx,$chr_lt_min_depth_idx) = which_both($padded_value);
    unless ($chr_gt_min_depth_idx->nelem) {
        return;
    }
    my $gt_first = $chr_gt_min_depth_idx(0)->sclr;
    my $lt_first = $chr_lt_min_depth_idx(0)->sclr;

    my $gt_last = $chr_gt_min_depth_idx(-1)->sclr;
    my $lt_last = $chr_lt_min_depth_idx(-1)->sclr;

    my $start = $padded_quantity_cumsum->index($chr_lt_min_depth_idx);
    my $end = $padded_quantity_cumsum->index($chr_gt_min_depth_idx);

    if ($gt_first < $lt_first) {
        # Coverage first because the first index is zero
        # Add the initial start position(ie. zero)
        $start = append(zeroes(1),$start);
    }
    if ($gt_last < $lt_last) {
        # Gap on the end, remove the last value
        $start = $start(0:-2);
    }
    my @clusters;
    for (my $i = 0; $i < $start->getdim(0); $i++) {
        # Start is zero-based and End is one-based, just like BED format
        my $start_coordinate = $start($i)->sclr;
        # The end position is really the start of the gap
        my $end_coordinate = $end($i)->sclr - 1;
        my $cluster_pdl = $chr_pdl($start_coordinate:$end_coordinate)->sever;
        my ($gt_idx,$zero_idx) = which_both($cluster_pdl >= $min_depth);
        # TODO: This can be removed once everything is validated
        if ($zero_idx->getdim(0)) {
            die('Unexpected number in PDL: '. $start_coordinate ."\t". $end_coordinate ."\t". $cluster_pdl);
        }
        my $start_pos = $start_coordinate + $offset;
        my $end_pos = $end_coordinate + $offset + 1;
        push @clusters, [ $start_pos, $end_pos, $cluster_pdl];
    }
    return @clusters;
}


1;
