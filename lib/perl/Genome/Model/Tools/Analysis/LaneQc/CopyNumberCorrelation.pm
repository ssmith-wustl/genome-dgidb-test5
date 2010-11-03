package Genome::Model::Tools::Analysis::LaneQc::CopyNumberCorrelation;

use warnings;
use strict;
use Genome;
use IO::File;

class Genome::Model::Tools::Analysis::LaneQc::CopyNumberCorrelation {
    is => 'Command',
    has => [
    copy_number_laneqc_file_glob => {
        type => 'FilePath',
        is_optional => 0,
        doc => 'glob string for grabbing copy-number laneqc files to compare',
    },
    output_file => {
        type => 'FilePath',
        is_optional => 0,
        doc => 'output filename',
    },
    ]
};

sub help_brief {
    "Script to create a correlation matrix from copy-number lane-qc data."
}
sub help_detail {
    "Script to create a correlation matrix from copy-number lane-qc data."
}

sub execute {
    my $self = shift;

    #parse inputs
    my $fileglob = $self->copy_number_laneqc_file_glob;
    my @cnfiles = sort glob($fileglob);
    my $num_files = $#cnfiles;
    my $outfile = $self->output_file;
    #print "@cnfiles\n"; #to test

    #Check that files are reasonably similar
    my $standard_wc;
    for my $file (@cnfiles) {
        my $wc_call = `wc -l $file`;
        my ($wc) = $wc_call =~ m/^(\d+)\s+\w+$/;
        unless ($standard_wc) { 
            $standard_wc = $wc; 
            next;
        }
        my $wc_diff = $standard_wc - $wc;
        $wc_diff = abs($wc_diff);
        if ($wc_diff > 100) {
            $self->status_message("Files have largely varied wordcounts (diff>100) - just letting you know in case this is of concern.");
        }
    }

    #Loop through copy-number files to create correlation matrix
    my %corr_matrix;
    for my $i1 (0..$num_files) {
        my $loop2index = $i1 + 1;
        for my $i2 ($loop2index..$num_files) {
            next if $cnfiles[$i1] eq $cnfiles[$i2];
            my $corr = `R --slave --args $cnfiles[$i1] $cnfiles[$i2] < /gscuser/ndees/scripts/cn_correlation_script.R`;
            $corr_matrix{$cnfiles[$i1]}{$cnfiles[$i2]} = $corr;
        }
    }

    #print output
    my $out_fh = new IO::File $outfile,"w";
    for my $f1 (sort keys %corr_matrix) {
        for my $f2 (sort keys %{$corr_matrix{$f1}}) {
            my $line = join("\t",$f1,$f2,$corr_matrix{$f1}{$f2});
            print $out_fh "$line\n";
        }
    }
    $out_fh->close;

    return 1;
}
1;
