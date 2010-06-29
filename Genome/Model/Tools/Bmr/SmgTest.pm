package Genome::Model::Tools::Bmr::SmgTest;

use strict;
use warnings;
use Genome;
use Cwd;

class Genome::Model::Tools::Bmr::SmgTest {
    is => 'Command',
    has => [
    bmr_file => {
        is => 'String',
        is_optional => 0,
        doc => 'File containing per-gene BMR info.',
    },
    output_file => {
        is => 'String',
        is_optional => 1,
        doc => 'SMG test output.',
    },
    ]
};

sub help_brief {
    "Run the SMG test in R."
}

sub help_detail {
    "Takes as input output from gmt bmr calculate-bmr, and run's Qunyuan's SMG test which is coded in R."
}

sub execute {
    my $self = shift;
    my $rlibrary = "SMG_test.R";
    my $infile = $self->bmr_file;
    unless (-s $infile) {
        $self->status_message("BMR file not found.");
        return;
    }
    my $outfile = $self->output_file;
    unless ($outfile) {
        $outfile = $infile . ".smgtest";
    }

    my $smg_test_cmd = "smg_test(in.file='$infile',out.file='$outfile');";
    my $smg_test_rcall = Genome::Model::Tools::R::CallR->create(command=>$smg_test_cmd,library=>$rlibrary);
    $smg_test_rcall->execute;

    return 1;
}
1;
