package Genome::Model::Tools::OldRefCov::Progression;

use strict;
use warnings;

use Genome;
use GD::Graph::lines;

class Genome::Model::Tools::OldRefCov::Progression {
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
                                   },
                     instrument_data_ids => { },
                 ],
};

sub create {
    my $class = shift;
    my %params = @_;
    my $stats_files = delete $params{stats_files};
    my $instrument_data_ids = delete $params{instrument_data_ids};
    my $self = $class->SUPER::create(%params);
    $self->stats_files($stats_files);
    if ($instrument_data_ids) {
        my @stats_files = @{$stats_files};
        my @instrument_data_ids = @{$instrument_data_ids};
        unless (scalar(@stats_files) eq scalar(@instrument_data_ids)) {
            die('Unbalanced number of stats files and instrument data ids!');
        }
        $self->instrument_data_ids($instrument_data_ids);
    }
    return $self;
}

sub execute {
    my $self = shift;

    my %progression;
    my $current_interval = $self->interval;
    
    my @stats_files = @{$self->stats_files};
    for (my $i = 0; $i < scalar(@stats_files); $i++) {
        my $stats_file = $stats_files[$i];
        my $stats_fh = Genome::Sys->open_file_for_reading($stats_file);
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
        $progression{$current_interval}{'bases_covered'} = $bases_covered;
        $progression{$current_interval}{'reference_bases'} = $reference_bases;
        if ($self->instrument_data_ids) {
            my @instrument_data_ids = @{$self->instrument_data_ids};
            my $instrument_data_id = $instrument_data_ids[$i];
            my $rls = GSC::RunLaneSolexa->get($instrument_data_id);
            if ($rls) {
                my $error_avg = $rls->filt_error_rate_avg;
                my $error_stdev = $rls->filt_error_rate_stdev;
                $progression{$current_interval}{'interval_id'} = $instrument_data_id;
                $progression{$current_interval}{'interval_error_avg'} = $error_avg;
                $progression{$current_interval}{'interval_error_stdev'} = $error_stdev;
            }
        }
        $current_interval += $self->interval;
    }
    my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
    unless ($output_fh) {
        $self->error_message('Failed to open output file '. $self->output_file .' for writing!');
        return;
    }
    # Report results
    my @intervals;
    my @coverage;
    my $prior_pc_coverage = 0;
    foreach my $interval (sort {$a <=> $b} keys %progression) {
        my $bases_covered = $progression{$interval}{'bases_covered'};
        my $reference_bases = $progression{$interval}{'reference_bases'};
        my $pc_coverage = sprintf("%.02f", (($bases_covered / $reference_bases) * 100) );
        push @intervals, $interval;
        push @coverage, $pc_coverage;
        my $pc_gain = sprintf("%.02f",($pc_coverage - $prior_pc_coverage) );
        print $output_fh $interval ."\t".$bases_covered ."\t". $reference_bases ."\t". $pc_coverage ."\t". $pc_gain;
        if (defined($progression{$interval}{'interval_id'})) {
            my $interval_id = $progression{$interval}{'interval_id'};
            my $error_avg = $progression{$interval}{'interval_error_avg'};
            my $error_stdev = $progression{$interval}{'interval_error_stdev'};
            print $output_fh "\t". $interval_id ."\t". $error_avg ."\t". $error_stdev;
        }
        print $output_fh "\n";

        $prior_pc_coverage = $pc_coverage;
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


