package Genome::Model::Tools::Analysis::LaneQc::CopyNumberCorrelation;

use warnings;
use strict;
use Genome;
use Cwd;
use Statistics::R;
require Genome::Utility::FileSystem;

class Genome::Model::Tools::Analysis::LaneQc::CopyNumberCorrelation {
    is => 'Command',
    has => [
    copy_number_laneqc_glob => {
        type => 'FilePath',
        is_optional => 0,
        doc => 'glob string for grabbing copy-number laneqc files',
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
    $DB::single = 1;
    my $fileglob = $self->copy_number_laneqc_glob;
    my @cnfiles = glob($fileglob);
    print "@cnfiles\n"; #to test

    #Check that files are reasonably similar
    my $standard_wc;
    for my $file (@cnfiles) {
        my $wc = `wc -l $file`;
        $wc =~ s/^(\d+)\s+\w+$/$1/;
        unless ($standard_wc) { 
            $standard_wc = $wc; 
            next;
        }
        my $wc_diff = $standard_wc - $wc;
        $wc_diff = abs($wc_diff);
        if ($wc_diff > 100) {
            $self->status_message("Files have varied wordcounts (diff>100) - just letting you know in case this is of concern.");
        }
    }

    #create temp directory for R to operate within 
    my $tempdir = Genome::Utility::FileSystem->create_temp_directory();
    my $cwd = cwd();
    my $R = Statistics::R->new(tmp_dir => $tempdir);
    $R->startR();

    #Loop through copy-number files to create correlation matrix
    for my $file (sort @cnfiles) {
        print "$file\n";
        $R->send(qq{
            y=2;
            stop(paste("printing output",y,sep="\t"), call. = FALSE);
            });
        my $ret = $R->read();
        print "at test\n";
        my $testfile = "/gscuser/ndees/git/genome/lib/perl/Genome/Model/Tools/Analysis/LaneQc/test.txt";
        print "here 1\n";
        my $fh = new IO::File $testfile,"w";
        print "here 2\n";
        print $fh "$ret\n";
        print $fh "2nd line\n";
        print "here 3\n";
        $fh->close;
        print "after test\n";
        #print "$ret";
    }



    $R->stopR();
    chdir $cwd;

    #print some output maybe
    return 1;
}
1;
