package Genome::Model::Tools::RefCov::Progression;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::Progression {
    is => ['Command'],
    has => [
            stats_files => {
                            is => 'List',
                            doc => 'all the stats files in order to produce progression',
                        },
            output_file => {
                            is => 'Text',
                            doc => 'The output file path to dump the results',
                        },
        ],
    has_optional => [

                     image_file => {
                                    is => 'Text',
                                    doc => 'The output png file path to dump the graph',
                                    is_optional => 1,
                                },
                     sample_name => {
                                     is => 'Text', default_value => '',
                                 },
                     interval => {
                                  is => 'Text',
                                  default_value => '1',
                              },
                     interval_unit => {
                                       is => 'Text',
                                       default_value => 'Lanes',
                                   }
                 ],
};

sub execute {
    my $self = shift;

    my %progression;
    my $current_interval = $self->interval;
    for my $stats_file (@{$self->stats_files}) {
        my $stats_fh = Genome::Utility::FileSystem->open_file_for_reading($stats_file);
        unless ($stats_fh) {
            $self->error_message("Failed to open stats file '$stats_file' for reading:  $!");
            die ($self->error_message);
        }
        my $reference_bases = 0;
        my $bases_covered = 0;
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
            my @entry = split("\t",$line);
            $reference_bases += $entry[2];
            $bases_covered += $entry[3];
        }
        $progression{$current_interval} = sprintf("%.02f", (($bases_covered / $reference_bases) * 100) );
        $current_interval += $self->interval;
    }
    my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($self->output_file);
    unless ($output_fh) {
        $self->error_message('Failed to open output file '. $self->output_file .' for writing!');
        return;
    }
    # Report results
    my @intervals;
    my @coverage;
    foreach my $interval (sort {$a <=> $b} keys %progression) {
        my $pc_coverage = $progression{$interval};
        push @intervals, $interval;
        push @coverage, $pc_coverage;
        print $output_fh $interval ."\t". $pc_coverage ."\n";
    }
    $output_fh->close;
    if ($self->image_file) {
        my @data = (\@intervals,\@coverage);
        my $graph = GD::Graph::lines->new(1200,800);
        $graph->set(
                    'x_label' => ucfirst($self->interval_unit),
                    'y_label' => "Coverage(%)",
                    'title' => $self->sample_name ." Coverage Progression ",
                );
        my $gd = $graph->plot(\@data);
        open(IMG, '>'. $self->image_file) or die $!;
        binmode IMG;
        print IMG $gd->png;
        close IMG;
    }
    return 1;
}
