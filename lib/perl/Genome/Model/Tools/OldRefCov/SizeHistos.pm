package Genome::Model::Tools::OldRefCov::SizeHistos;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::OldRefCov::SizeHistos {
    is => ['Command'],
    has_input => [
                  stats_file => {
                                  is => 'Text',
                                  doc => 'The stats tsv file produed by ref-cov.',
                              },
                  output_file => {
                                  is => 'Text',
                                  doc => 'The output file path to dump the results',
                                  is_optional => 1,
                              },
              ],
};

sub execute {
    my $self = shift;

    my $oldout;
    if ($self->output_file) {
        open $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
        my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
        unless ($output_fh) {
            $self->error_message('Failed to open output file '. $self->output_file .' for writing!');
            return;
        }
        STDOUT->fdopen($output_fh,'w');
    }

    # Data structures for holding main information.
    my %ref;

    # Reading in the STATS.tsv file information.
    my $stats_fh = Genome::Sys->open_file_for_reading($self->stats_file);
    unless ($stats_fh) {
        $self->error_message('Failed to open stats file '. $self->stats_file ." for reading:  $!");
        return;
    }
    while (my $line = $stats_fh->getline) {
        # [0]  Reference Name
        # [1]  Percent of Reference Bases Covered
        # [2]  Total Number of Reference Bases
        # [3]  Total Number of Covered Bases
        # [4]  Number of Missing Bases
        # [5]  Average Coverage Depth
        # [6]  Standard Deviation Average Coverage Depth
        # [7]  Median Coverage Depth
        # [8]  Number of Gaps
        # [9]  Average Gap Length
        # [10] Standard Deviation Average Gap Length
        # [11] Median Gap Length
        # [12] Min. Depth Filter
        # [13] Discarded Bases (Min. Depth Filter)
        chomp($line);
        my @fields = split (/\t/, $line);
        my $ref             = $fields[0];
        $ref{$ref}->{cov}   = $fields[1];
        $ref{$ref}->{size}  = $fields[2];
        $ref{$ref}->{depth} = $fields[5]
    }
    $stats_fh->close;

    # Walk through reference BIN sizes and act on each bin independently.
    my $bin_sizes = {
                     1  => [1,         500],
                     2  => [501,       1_000],
                     3  => [1_001,     2_000],
                     4  => [2_001,     3_000],
                     5  => [3_001,     4_000],
                     6  => [4_001,     5_000],
                     7  => [5_001,     6_000],
                     8  => [6_001,     7_000],
                     9  => [7_001,     8_000],
                     10 => [8_001,     9_000],
                     11 => [9_001,     10_000],
                     12 => [10_001,    11_000],
                     13 => [11_001,    12_000],
                     14 => [12_001,    13_000],
                     15 => [13_001,    14_000],
                     16 => [14_001,    15_000],
                     17 => [15_000, 1_000_000],  # catch all
                 };
    my $range_sizes = {
                       1  => [0,     0],
                       2  => [0.01,  10],
                       3  => [10.01, 20],
                       4  => [20.01, 30],
                       5  => [30.01, 40],
                       6  => [40.01, 50],
                       7  => [50.01, 60],
                       8  => [60.01, 70],
                       9  => [70.01, 80],
                       10 => [80.01, 90],
                       11 => [90.01, 99.99],
                       12 => [100,  100],
                   };
    foreach my $bin (sort {$a <=> $b} keys %{$bin_sizes}) {
        # Gather information based on BIN size.
        my $bininfo = {};

        # Check for reference inclusion in BIN.
      BININCLUSION:
        foreach my $refinfo (keys %ref) {
            if ( $ref{$refinfo}->{size} >= $bin_sizes->{$bin}[0] &&
                 $ref{$refinfo}->{size} <= $bin_sizes->{$bin}[1] ) {
                # Inclusion.
                $bininfo->{total_num_genes}++;
              RANGEINCLUSION:
                foreach my $range (sort {$a <=> $b} keys %{$range_sizes}) {
                    if ( $ref{$refinfo}->{cov} >= $range_sizes->{$range}[0] &&
                         $ref{$refinfo}->{cov} <= $range_sizes->{$range}[1] ) {
                        $bininfo->{perc_cov}->{$range}++;
                        $bininfo->{depth_cov}->{$range}++;
                    } else {
                        next RANGEINCLUSION;
                    }
                }
            } else {
                # Exclusion.
                next BININCLUSION;
            }
        }

        # Report on BINs; there are 10 ranges per bin.
        print "BIN SUMMARY: " . $bin_sizes->{$bin}[0] . ' - ' . $bin_sizes->{$bin}[1] . "\n";
        print "\tTOTAL GENES IN BIN: " . $bininfo->{total_num_genes} . "\n";

        foreach my $range_val (sort {$a <=> $b} keys %{$range_sizes}) {
            if ($bininfo->{perc_cov}->{$range_val}) {
                my $percent = ($bininfo->{perc_cov}->{$range_val} / $bininfo->{total_num_genes}) * 100;
                $percent    = sprintf( "%.2f", $percent );
                if ($range_val == 1 || $range_val == 12) {
                    print "\t\t" . $range_sizes->{$range_val}[0] . "%\t\t\t" . $bininfo->{perc_cov}->{$range_val} . "\t" . $percent . "%\n";
                } else {
                    print "\t\t" . $range_sizes->{$range_val}[0] . '% - ' . $range_sizes->{$range_val}[1] . "%\t\t" . $bininfo->{perc_cov}->{$range_val} . "\t" . $percent . "%\n";
                }
            } else {
                print "\t\t" . $range_sizes->{$range_val}[0] . '% - ' . $range_sizes->{$range_val}[1] . "%\t\t" . "0\t0%\n";
            }
        }
        print "||\n";
    }
    if ($oldout) {
        open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
    }
    return 1;
}

__END__
