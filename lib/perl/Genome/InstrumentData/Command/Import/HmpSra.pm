package Genome::InstrumentData::Command::Import::HmpSra;

use strict;
use warnings;
use Genome;
use Cwd;

class Genome::InstrumentData::Command::Import::HmpSra {
    is  => 'Command',
    has_input => [
        run_ids => { 
            is_many => 1, 
            doc => 'the SRR ids of the data',
        },
        tmp_dir => {
            is_optional => 1,
            doc => 'override the temp dir used during processing (no auto cleanup)',
        },
    ],
    doc => 'download an import short read archive HMP data',
};

sub execute {
    my $self = shift;
    
    my @srr_ids = $self->run_ids;
    $self->status_message("SRR ids are: @srr_ids");

    my $tmp = $self->tmp_dir;
    if ($tmp) {
        unless (-d $tmp) {
            die "temp directory $tmp not found!";
        }
        $self->status_message("Override temp dir is $tmp");
    }
    else {
        $tmp = Genome::Utility::FileSystem->create_temp_directory();
        $self->status_message("Autogenerateed temp data is in $tmp");
    }

    my $junk_tmp = $tmp . '/junk';
    Genome::Utility::FileSystem->create_directory($junk_tmp);

    my $scripts_dir = __FILE__;
    $scripts_dir =~ s/.pm//;
    $self->status_message("Scripts are in: $scripts_dir");    

    my $errfile;
    my $cmd;

    # build the SRA index
    my $index_file = $tmp . '/SRA-index.txt';
    $errfile = $index_file . '.err';
    $cmd = "cd $junk_tmp; $scripts_dir/build_public_SRA_run_index.pl --reuse_files "
        . ' > ' . $index_file 
        . ' 2> ' . $errfile;        
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        output_files => [$index_file,$errfile],
        skip_if_output_is_present => 1,
    );

    # download each
    # TODO: it may be better to do in bulk, or better individually7 for max speed per item
    for my $srr_id (@srr_ids) {
        my $fof = "$tmp/$srr_id.fof";
        Genome::Utility::FileSystem->write_file($fof, $srr_id);
        
        my $log = $fof;
        $log =~ s/.fof/.log/;

        my $results_dir = "$tmp/$srr_id";

        if (-d $results_dir) {
            $self->status_message("Found directory, skipping download: $results_dir");
        }
        else {
            my $cmd = "cd $tmp; $scripts_dir/get_SRA_runs.pl ascp $index_file $fof";        
            Genome::Utility::FileSystem->shellcmd(
                cmd => $cmd,
                input_files => [$fof],
                output_directories => [$results_dir],
                skip_if_output_is_present => 1,
            );
        }
    }

    return 1;
}

1;

