package Genome::Model::Tools::BioSamtools::StatsSummary;

use strict;
use warnings;

use Genome;
use Statistics::Descriptive;

class Genome::Model::Tools::BioSamtools::StatsSummary {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        stats_file => {
            is => 'Text',
            doc => 'A STATS file output from refcov',
        },
        output_directory => {
            doc => 'When run in parallel, this directory will contain all output files. Do not define if output_file is defined.',
            is_optional => 1
        },
    ],
    has_output => [
        output_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'The output file to write summary stats',
        },
    ],
};

sub help_detail {
    'This command takes the STATS file from refcov and generates summary statistics based on all regions/targets.  This command will run on 32 or 64 bit architechture'
}

sub execute {
    my $self = shift;
    
    if ($self->output_directory) {
        unless (-d $self->output_directory){
            unless (Genome::Utility::FileSystem->create_directory($self->output_directory)) {
                die('Failed to create output directory '. $self->output_directory);
            }
        }
    }
    unless ($self->output_file) {
        my ($basename,$dirname,$suffix) = File::Basename::fileparse($self->stats_file,qw/.tsv/);
        unless (defined($suffix)) {
            die('Failed to recognize stats_file '. $self->stats_file .' without a tsv suffix');
        }
        $self->output_file($self->output_directory .'/'. $basename .'.txt');
    }
    my $stats_fh = Genome::Utility::FileSystem->open_file_for_reading($self->stats_file);
    unless ($stats_fh) {
        die('Failed to read file stats file: '. $self->stats_file);
    }
    my $out_fh = Genome::Utility::FileSystem->open_file_for_writing($self->output_file);
    unless ($out_fh) {
        die('Failed to open output file: '. $self->output_file);
    }
    
    my %stats;
    my $targets = 0;
    my $target_base_pair = 0;
    my $covered_base_pair = 0;
    my $touched = 0;
    my $eighty_pc = 0;
    my $gaps = 0;
    my $min_depth;
    my @breadth;
    my @depth;
    my @gap_length;
    while (my $line = $stats_fh->getline) {
        chomp($line);
        if ($line =~ /^##/) { next; }
        my @entry = split("\t",$line);
        my $id = $entry[0];
        $stats{$id}{'breadth'} = $entry[1];
        $stats{$id}{'base_pair'} = $entry[2];
        $stats{$id}{'base_pair_covered'} = $entry[3];
        $stats{$id}{'base_pair_uncovered'} = $entry[4];
        $stats{$id}{'avg_depth'} = $entry[5];
        $stats{$id}{'std_depth'} = $entry[6];
        $stats{$id}{'med_depth'} = $entry[7];
        $stats{$id}{'num_gaps'} = $entry[8];
        $stats{$id}{'avg_gap_length'} = $entry[9];
        $stats{$id}{'std_gap_length'} = $entry[10];
        $stats{$id}{'med_gap_length'} = $entry[11];
        $stats{$id}{'min_depth'} = $entry[12];

        push @breadth, $stats{$id}{'breadth'};
        if ($stats{$id}{'breadth'} >= 80) {
            $eighty_pc++;
        }
        $target_base_pair += $stats{$id}{'base_pair'};
        $covered_base_pair += $stats{$id}{'base_pair_covered'};
        if ($stats{$id}{'base_pair_covered'}) {
            $touched++;
        }
        push @depth, $stats{$id}{'avg_depth'};
        if ($stats{$id}{'num_gaps'}) {
            $gaps += $stats{$id}{'num_gaps'};
            push @gap_length, $stats{$id}{'avg_gap_length'};
        }

        unless (defined($min_depth)) {
            $min_depth = $stats{$id}{'min_depth'};
        } else {
            unless ($min_depth == $stats{$id}{'min_depth'}) {
                die('Error in '. $self->stats_file .' expected min_depth '. $min_depth .' but found min_depth '. $stats{$id}{'min_depth'} .' for line: '. $line);
            }
        }
        $targets++;
    }
    $stats_fh->close;
    my $breadth_stat = Statistics::Descriptive::Full->new();
    $breadth_stat->add_data(@breadth);

    my $depth_stat = Statistics::Descriptive::Full->new();
    $depth_stat->add_data(@depth);

    my $gaps_stat = Statistics::Descriptive::Full->new();
    $gaps_stat->add_data(@gap_length);

    print $out_fh $self->stats_file ."\n";
    print $out_fh "-" x 20 ."\n";
    print $out_fh "Target Summary\n";
    print $out_fh "\tTargets:\t$targets\n";
    print $out_fh "\tMinimum Depth:\t$min_depth\n";
    print $out_fh "\tTargets Touched:\t$touched\n";
    print $out_fh "\tPercent Targets Touched:\t". sprintf("%.03f",(($touched/$targets)*100)) ."%\n";
    print $out_fh "-" x 20 ."\n";
    print $out_fh "Breadth Summary\n";
    print $out_fh "\tTarget Space(bp):\t". $target_base_pair ."\n";
    print $out_fh "\tTarget Space Covered(bp):\t". $covered_base_pair ."\n";
    print $out_fh "\tPercent Target Space Covered:\t". sprintf("%.03f",(($covered_base_pair/$target_base_pair)*100)) ."%\n";
    print $out_fh "\tAverage Percent Breadth:\t". sprintf("%.03f",$breadth_stat->mean) ."%\n";
    print $out_fh "\tStd. Deviation Breadth:\t". sprintf("%.10f",$breadth_stat->standard_deviation) ."\n";
    print $out_fh "\tMedian Breadth:\t". sprintf("%.03f",$breadth_stat->median) ."\n";
    print $out_fh "\tTargets 80% Breadth:\t". $eighty_pc ."\n";
    print $out_fh "\tPercent Targets 80% Breadth:\t". sprintf("%.03f",(($eighty_pc/$targets)*100)) ."%\n";
    print $out_fh "-" x 20 ."\n";
    print $out_fh "Depth Summary\n";
    print $out_fh "\tAverage Depth:\t". sprintf("%.03f",$depth_stat->mean) ."\n";
    print $out_fh "\tStd. Deviation Depth:\t". sprintf("%.10f",$depth_stat->standard_deviation) ."\n";
    print $out_fh "\tQuartile 3:\t". sprintf("%.03f",$depth_stat->percentile(75)) ."\n";
    print $out_fh "\tMedian Depth:\t". sprintf("%.03f",$depth_stat->median) ."\n";
    print $out_fh "\tQuarile 1:\t". sprintf("%.03f",$depth_stat->percentile(25)) ."\n";
    print $out_fh "-" x 20 ."\n";
    print $out_fh "Gap Summary\n";
    print $out_fh "\tTotal Gaps:\t". $gaps ."\n";
    print $out_fh "\tAverage Gap Length:\t". sprintf("%.03f",$gaps_stat->mean) ."\n";
    print $out_fh "\tStd. Deviation Gap Length:\t". sprintf("%.10f",$gaps_stat->standard_deviation) ."\n";
    print $out_fh "\tMedian Gap Length:\t". sprintf("%.03f",$gaps_stat->median) ."\n";
    print $out_fh "-" x 20 ."\n\n";
    $out_fh->close;
    return 1;
}

1;
