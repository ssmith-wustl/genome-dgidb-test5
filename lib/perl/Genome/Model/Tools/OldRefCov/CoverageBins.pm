package Genome::Model::Tools::OldRefCov::CoverageBins;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::OldRefCov::CoverageBins {
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
        $ref{$ref}->{depth} = $fields[5];
    }
    $stats_fh->close;

    # TODO: make this an input param
    my %bins;
    foreach my $ref (keys %ref) {
        my $size = $ref{$ref}->{size};
        my $cov    = $ref{$ref}->{cov};
        if (($size >= 100) && ($size <= 2_999)) {
            if ($cov >= 90) {
                $bins{SMALL_COVERED}++;
            }
            $bins{SMALL_TOTAL}++;
        }
        elsif (($size >= 3_000) && ($size <= 6_999)) {
            if ($cov >= 50) {
                $bins{MEDIUM_COVERED}++;
            }
            $bins{MEDIUM_TOTAL}++;
        }
        elsif (($size >= 7_000)) {
            if ($cov >= 30) {
                $bins{LARGE_COVERED}++;
            }
            $bins{LARGE_TOTAL}++;
        }
    }
    my %desc = (
                SMALL => 'SMALL(>=100,<=2999,1X,90%)',
                MEDIUM => 'MEDIUM(>=3000,<=6999,1X,50%)',
                LARGE => 'LARGE(>=7000,1X,30%)',
            );
    for my $key ('SMALL', 'MEDIUM', 'LARGE') {
        my $covered = $bins{$key .'_COVERED'};
        my $total = $bins{$key .'_TOTAL'};
        my $pc = sprintf("%.02f",(($covered / $total) * 100));
        print $desc{$key} .":\t".  $covered .'/'. $total ."\t". $pc ."%\n";
    }
    if ($oldout) {
        open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
    }
    return 1;
}

__END__
