package Genome::Model::Tools::Cmds::Execute;

use warnings;
use strict;
use Genome;
use Cwd;
use LSF::Job;

class Genome::Model::Tools::Cmds::Execute {
    is => 'Command',
    has => [
    data_directory => {
        type => 'String',
        is_optional => 0,
        doc => 'Directory containing all of the input files for sample group (and nothing else!!).',
    },
    output_directory => {
        type => 'String',
        is_optional => 1,
        default => getcwd(),
        doc => 'Directory for output folders cmds_test and cmds_plot to be created. Default: current working directory.',
        
    },
    ]
};

sub help_brief {
    "Run CMDS analysis"
}

sub help_detail {
    "This script runs the CMDS tool written by Qunyuan. It submits a job array to parallelize the process by chromosome. The process runs on every file in the data directory, so make sure it is clean. It creates two folders for output in the 'output_directory', one called cmds_test, containing text files of results, and a second caled cmds_plot, containing results in the form of images. DO NOT RUN THIS SCRIPT IN THE DATA DIRECTORY."
}

sub execute {
    my $self = shift;

    #define input and output directories
    my $data_dir = $self->data_directory;
    my $output_dir = $self->output_directory;
    my $plot_dir = $output_dir . "/cmds_plot";
    my $test_dir = $output_dir . "/cmds_test";
    
    #submit an R job for each chromosome input file
    my $index = 1;
    opendir DATA_DIR,$data_dir;
    while (my $file = readdir DATA_DIR) {
        next if ($file eq "." || $file eq "..");
        my $command = "cmds.focal.test(data.dir='$data_dir',wsize=30,wstep=1,analysis.ID='$index',chr.colname='CHR',pos.colname='POS',plot.dir='$plot_dir',result.dir='$test_dir');";
        my $job = "gmt r call-r --command \"$command\" --library 'cmds_lib.R'";
        my $job_name = "cmds_" . $file . "_index_" . $index;
        my $oo = $output_dir . "/cmds_" . $file . "_index_" . $index . "_STDOUT";
        LSF::Job->submit(-oo => $oo, -J => $job_name, $job);
        $index++;
    }

    return 1;
}
1;
