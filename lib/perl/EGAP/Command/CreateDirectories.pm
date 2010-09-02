package EGAP::Command::CreateDirectories;

use strict;
use warnings;

use EGAP;

use Carp qw(confess);
use File::Path qw(make_path);

class EGAP::Command::CreateDirectories {
    is => 'EGAP::Command',
    has => [
        output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'Output directory specified by user',
        },
    ],
    has_optional => [
        split_fastas_output_directory => {
            is => 'Path',
            is_output => 1,
            doc => 'Output directory for the split fastas',
        },
        masked_fastas_output_directory => {
            is => 'Path',
            is_output => 1,
            doc => 'Output directory for the masked fasta files',
        },
        fgenesh_output_directory => {
            is => 'Path',
            is_output => 1,
            doc => 'Output directory for raw fgenesh output',
        },
        rnammer_output_directory => {
            is => 'Path',
            is_output => 1,
            doc => 'Output directory for raw rnammer output',
        },
        rfamscan_output_directory => {
            is => 'Path',
            is_output => 1,
            doc => 'Output directory for raw rfamscan output',
        },
        snap_output_directory => {
            is => 'Path',
            is_output => 1,
            doc => 'Output directory for raw snap output',
        },
        trnascan_output_directory => {
            is => 'Path',
            is_output => 1,
            doc => 'Output directory for raw trnascan output',
        },
    ],
};

sub execute {
    my $self = shift;
    my $base_dir = $self->output_directory;
    
    if (-d $base_dir) {
        $self->warning_message("Output directory already exists at $base_dir, removing it!");
        my $rm_rv = system("rm -rf $base_dir");
        confess "Could not remove existing output at $base_dir!" unless defined $rm_rv and $rm_rv == 0;
    }

    my $base_mkdir = make_path($base_dir);
    confess "Could not make directory $base_dir!" unless $base_mkdir;
    $self->status_message("Output directory created at $base_dir, creating subdirectories.");

    my @sub_dirs = qw/ split_fastas fgenesh rnammer rfamscan snap trnascan masked_fastas /;

    for my $sub_dir (@sub_dirs) {
        my $abs_path = $base_dir . "/" . $sub_dir;
        my $rv = mkdir $abs_path;
        confess "Could not make directory $abs_path!" unless $rv;

        my $parameter = $sub_dir . "_output_directory";
        $self->{$parameter} = $abs_path;

        $self->status_message("Created $abs_path");
    }

    $self->status_message("All subdirectories successfully created!");
    return 1;
}

1;

