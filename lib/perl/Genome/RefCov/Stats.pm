package Genome::RefCov::Stats;

use strict;
use warnings;

use Statistics::Descriptive;

class Genome::RefCov::Stats {
    has => [
        coverage => {
            is => 'ArrayRef',
            doc => 'An array of integers representing the depth of coverage at each base position',
        },
        ref_length => {
            is_calculated => 1,
            calculate_from => ['coverage'],
            calculate => sub {
                my $coverage = shift;
                return scalar(@{$coverage});
            },
        },
        min_depth => {
            is => 'Integer',
            doc => 'The minimum depth to consider a base position covered',
            is_optional => 1,
            default_value => 0,
        },
    ],
    has_optional => {
        percent_ref_bases_covered   => {},
        #Redundant with ref_length
        total_ref_bases             => {},
        total_covered_bases         => {},
        missing_bases               => {},
        ave_cov_depth               => {},
        sdev_ave_cov_depth          => {},
        med_cov_depth               => {},
        gap_number                  => {},
        ave_gap_length              => {},
        sdev_ave_gap_length         => {},
        med_gap_length              => {},
        #Redundant with min_depth
        min_depth_filter            => {},
        min_depth_discarded_bases   => {},
        percent_min_depth_discarded => {},
    },
};

sub create {
    my $class = shift;
    my %params = @_;
    my $coverage = delete($params{coverage});
    my $self = $class->SUPER::create(%params);
    $self->coverage($coverage);
    $self->_main_calculation_code;
    return $self;
}


sub _main_calculation_code {
    my $self = shift;

    # ** NOTE **
    # Thu Jul  9 21:35:35 CDT 2009
    # The min_depth filter permanently changes the incoming coverage-depth
    # string; all downstream interactions will be based on the revised
    # coverage-depth string values, where values not matching the minimum
    # criteria are set to "0".

    # ** NOTE **
    # Thu Jul  9 21:35:46 CDT 2009
    # The functions related to "redundancy" of start-sites has been deprecated
    # in this version. The values needed for these calcualtions was previously
    # provided by the RefCov layering engine. We may possibly be able to
    # re-introduce this functionality by delving into the pileup information
    # provided by the Bio::DB::Bam package--however, for now, we will not be
    # attempting redundancy calculations.

    # MAIN CALCULATIONS FOLLOW THIS LINE
    # _____________________________________________________________________________

    my @gaps;
    my $current_gap_length  = 0;
    my $discarded_bases     = 0;
    my $total_covered       = 0;

    my $p = -1;
    POSITION:
    foreach my $position (@{ $self->coverage() }) {
        $p++;
        if ($position > 0 && $position < $self->min_depth()) {
            $self->_set_depth_to_zero( $p );
            $position = 0;
            $discarded_bases++;
        }
        if ($position > 0) {
            # COVERAGE
            $total_covered++;
            push (@gaps, $current_gap_length) if ($current_gap_length > 0);
            $current_gap_length = 0;
        }
        else {
            # NO COVERAGE
            $current_gap_length++;
        }
    }
    $self->total_covered_bases( $total_covered );

    # Deal with a single (potential) hanging gap on terminal of SEQUENCE.
    if ($current_gap_length > 0) { push (@gaps, $current_gap_length) }

    map {$_ = 0} my (
                     $mean_pos_depth,
                     $med_pos_depth,
                     $stddev_pos_depth,
                     $mean_gap_size,
                     $med_gap_size,
                     $stddev_gap_size,
                    );

    # COVERAGE
    my $coverage_stat = Statistics::Descriptive::Full->new();
    $coverage_stat->add_data($self->coverage);
    $mean_pos_depth   = $coverage_stat->mean;
    $stddev_pos_depth = $coverage_stat->standard_deviation;
    $med_pos_depth    = $coverage_stat->median;

    # GAPS
    
    if (!@gaps) {
        # Empty array instance.
        map {$_ = '0'} ($med_gap_size, $stddev_gap_size, $mean_gap_size);
    } else {
        my $gap_stat = Statistics::Descriptive::Full->new();
        $gap_stat->add_data(\@gaps);
        $mean_gap_size   = $gap_stat->mean;
        $stddev_gap_size = $gap_stat->standard_deviation;
        $med_gap_size    = $gap_stat->median;
    }

    # --------------------------------------------------
    # F O R M A T
    # --------------------------------------------------
    # [0]   Percent of Reference Bases Covered
    # [1]   Total Number of Reference Bases
    # [2]   Total Number of Covered Bases
    # [3]   Number of Missing Bases
    # [4]   Average Coverage Depth
    # [5]   Standard Deviation Average Coverage Depth
    # [6]   Median Coverage Depth
    # [7]   Number of Gaps
    # [8]   Average Gap Length
    # [9]   Standard Deviation Average Gap Length
    # [10]  Median Gap Length
    # [11]  Min. Depth Filter
    # [12]  Discarded Bases (Min. Depth Filter)
    # [13]  Percent Discarded Bases (Min. Depth Filter)
    # (DEPRECATED)  [14]  Max. Unique Filter
    # (DEPRECATED)  [15]  Total Number of Reads Layered
    # (DEPRECATED)  [16]  Total Number of Unique Start Site Reads Layered
    # (DEPRECATED)  [17]  Percent Redundancy of Read Layers
    # (DEPRECATED)  [18]  Zenith
    # (DEPRECATED)  [19]  Nadir
    # --------------------------------------------------

    # [0] Percent of Reference Bases Covered
    $self->percent_ref_bases_covered( _round( ($self->total_covered_bases / $self->ref_length()) * 100 ) );

    # [1] Total Number of Reference Bases
    $self->total_ref_bases( $self->ref_length() );

    # [2] Total Number of Covered Bases
    # (... set above.)

    # [3] Number of Missing Bases
    $self->missing_bases( $self->ref_length() - $self->total_covered_bases() );

    # [4] Average Coverage Depth
    $self->ave_cov_depth( _round( $mean_pos_depth ) );

    # [5] Standard Deviation Average Coverage Depth
    $self->sdev_ave_cov_depth( _round( $stddev_pos_depth ) );

    # [6] Median Coverage Depth
    $self->med_cov_depth( _round( $med_pos_depth ) );

    # [7] Number of Gaps
    if (@gaps) {
        $self->gap_number( scalar( @gaps ) );
    }
    else {
        $self->gap_number( '0' );
    }

    # [8] Average Gap Length
    $self->ave_gap_length( _round( $mean_gap_size ) );

    # [9] Standard Deviation Average Gap Length
    $self->sdev_ave_gap_length( _round( $stddev_gap_size ) );

    # [10] Median Gap Length
    $self->med_gap_length( _round( $med_gap_size ) );

    # [11] Min. Depth Filter
    $self->min_depth_filter( $self->min_depth() );

    # [12] Discarded Bases (Min. Depth Filter)
    $self->min_depth_discarded_bases( $discarded_bases );

    # [13] Percent Discarded Bases (Min. Depth Filter)
    $self->percent_min_depth_discarded( _round( ($self->min_depth_discarded_bases() / $self->total_ref_bases()) * 100 ) );

    return $self;
}


sub _set_depth_to_zero {
    my ($self, $position) = @_;
    $self->coverage->[$position] = 0;  # revise string
    return $self;
}


sub _round {
    my $value = shift;
    return sprintf( "%.2f", $value );
}

sub stats {
    my $self = shift;

    # STATISTICS (no units attached, just values)
    my @stats = (
                 $self->percent_ref_bases_covered(),
                 $self->total_ref_bases(),
                 $self->total_covered_bases(),
                 $self->missing_bases(),
                 $self->ave_cov_depth(),
                 $self->sdev_ave_cov_depth(),
                 $self->med_cov_depth(),
                 $self->gap_number(),
                 $self->ave_gap_length(),
                 $self->sdev_ave_gap_length(),
                 $self->med_gap_length(),
                 $self->min_depth_filter(),
                 $self->min_depth_discarded_bases(),
                 $self->percent_min_depth_discarded(),
                );

    return \@stats;
}

sub stats_index {
    my $self = shift;

    # STATISTICS (no units attached, just values)
    my %stats = (
                 0  => { 'Percent of Reference Bases Covered'           => $self->percent_ref_bases_covered()   },
                 1  => { 'Total Number of Reference Bases'              => $self->total_ref_bases()             },
                 2  => { 'Total Number of Covered Bases'                => $self->total_covered_bases()         },
                 3  => { 'Number of Missing Bases'                      => $self->missing_bases()               },
                 4  => { 'Average Coverage Depth'                       => $self->ave_cov_depth()               },
                 5  => { 'Standard Deviation Average Coverage Depth'    => $self->sdev_ave_cov_depth()          },
                 6  => { 'Median Coverage Depth'                        => $self->med_cov_depth()               },
                 7  => { 'Number of Gaps'                               => $self->gap_number()                  },
                 8  => { 'Average Gap Length'                           => $self->ave_gap_length()              },
                 9  => { 'Standard Deviation Average Gap Length'        => $self->sdev_ave_gap_length()         },
                 10 => { 'Median Gap Length'                            => $self->med_gap_length()              },
                 11 => { 'Min. Depth Filter'                            => $self->min_depth_filter()            },
                 12 => { 'Discarded Bases (Min. Depth Filter)'          => $self->min_depth_discarded_bases()   },
                 13 => { 'Percent Discarded Bases (Min. Depth Filter)'  => $self->percent_min_depth_discarded() },
                );

    return \%stats;
}

sub save_stats {
    my ($self, $file) = @_;

    # Require a file path.
    if (!$file) { croak (__PACKAGE__ . ' method save_stats requires a "file" argument.'); }

    # Order stats by field keys and print to STDOUT, attach units
    open (OUT, ">$file") or die 'could not open save file for stats';
    foreach my $field_key (sort {$a <=> $b} keys %{ $self->stats_index() }) {
        foreach my $field_name (keys %{ $self->stats_index()->{$field_key} }) {
            my $line = sprintf( "%-45s %-15s\n", $field_name . ':', $self->stats_index()->{$field_key}->{$field_name});
            print OUT $line;
        }
    }
    close (OUT);

    return $self;
}

sub print_stats {
    my $self = shift;

    # Order stats by field keys and print to STDOUT, attach units
    foreach my $field_key (sort {$a <=> $b} keys %{ $self->stats_index() }) {
        foreach my $field_name (keys %{ $self->stats_index()->{$field_key} }) {
            printf( "%-45s %-15s\n", $field_name . ':', $self->stats_index()->{$field_key}->{$field_name});
        }
    }

    return $self;
}

sub as_string {
    my $self = shift;
    my $string = join ("\t", @{ $self->stats() });
    return $string;
}

1;
