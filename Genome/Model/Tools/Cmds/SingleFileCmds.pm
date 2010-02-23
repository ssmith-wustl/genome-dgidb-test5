package Genome::Model::Tools::Cmds::SingleFileCmds;

use warnings;
use strict;
use Genome;
use Cwd;
use Statistics::R;
require Genome::Utility::FileSystem;

class Genome::Model::Tools::Cmds::SingleFileCmds {
    is => 'Command',
    has => [
    data_directory => {
        type => 'String',
        is_optional => 0,
        doc => 'Directory containing all of the input files for sample group (and nothing else!!).',
    },
    output_directory => {
        type => 'String',
        is_optional => 0,
        doc => 'Directory for output folders cmds_test and cmds_plot to be created.',
    },
    file_index => {
        type => 'Number',
        is_optional => 0,
        doc => 'Number of file in directory to process (range is 1 to number of fiels in data_dir).'
    },
    ]
};

sub help_brief {
    "Run CMDS on a single chromosome file. This script intended to be called by Genome::Model::Tools::Cmds::Execute."
}

sub help_detail {
    "Run CMDS on a single chromosome file. This script intended to be called by Genome::Model::Tools::Cmds::Execute."
}

sub execute {

    my $self = shift;
    my $data_dir = $self->data_directory;
    #print "data_dir: $data_dir\n";
    my $output_dir = $self->output_directory;
    #print "output_dir: $output_dir\n";
    my $file_index = $self->file_index;
    #print "index: $file_index\n";
    my $plot_dir = $output_dir . "/cmds_plot";
    #print "plot_dir: $plot_dir\n";
    my $test_dir = $output_dir . "/cmds_test";
    #print "test_dir: $test_dir\n";

    #create temp dir for R to write to. R automatically sets the working directory to its tmp_dir, which prevents Genome::Utility::FileSystem from cleaning it up, so ssave the original dir beforehand and restore it after we're done
    my $tempdir = Genome::Utility::FileSystem->create_temp_directory();
    my $cwd = cwd();
    my $R = Statistics::R->new(tmp_dir => $tempdir);
    $R->startR();
    $R->send(qq{
        source('/gscuser/ndees/svn/checkout/Genome/Model/Tools/Cmds/cmds_lib.R');
        cmds.focal.test(data.dir='$data_dir',wsize=30,wstep=1,analysis.ID='$file_index',chr.colname='CHR',pos.colname='POS',plot.dir='$plot_dir',result.dir='$test_dir');
        });
    $R->stopR();
    $DB::single=1;
    chdir $cwd;

    return 1;
}

1;
    

