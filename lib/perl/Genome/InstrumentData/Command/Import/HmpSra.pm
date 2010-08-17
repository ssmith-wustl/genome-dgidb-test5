package Genome::InstrumentData::Command::Import::HmpSra;

use strict;
use warnings;
use Genome;
use Cwd;
use IO::File;

class Genome::InstrumentData::Command::Import::HmpSra {
    is  => 'Command',
    has_input => [
#        run_ids => { 
#            is_many => 1, 
##            doc => 'the SRR ids of the data',
#        },
	run_ids => { 
	    is_optional => 1, 
            doc => 'a file of SRR ids',
	},
        tmp_dir => {
            is_optional => 1,
            doc => 'override the temp dir used during processing (no auto cleanup)',
        },
#### jmartin ... 100813
        out_dir => {
            is_optional => 1,
            doc => 'location where SRA data objects will be copied into',
        },
    ],
    doc => 'download an import short read archive HMP data',
};

sub execute {
    my $self = shift;

    #### jmartin 100813
    ####my @srr_ids = $self->run_ids;
    my @srr_ids;
    my $fh = new IO::File $self->run_ids;
    while (<$fh>) {
	chomp;
	my $line = $_;
	next if ($line =~ /^\s*$/);
	push(@srr_ids,$line);
    }
    $fh->close;

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
    # TODO: it may be better to do in bulk, or better individually for max speed per item

    #### jmartin ... 100813
    my $output_dir;
    if (defined $self->out_dir) {
	$output_dir = $self->out_dir;
    } else {
	$output_dir = ".";
    }

    for my $srr_id (@srr_ids) {
        my $fof = "$tmp/$srr_id.fof";
        Genome::Utility::FileSystem->write_file($fof, $srr_id);
        
        my $log = $fof;
        $log =~ s/.fof/.log/;

	#### jmartin ... 100813
        ####my $results_dir = "$tmp/$srr_id";
	my $results_dir = "$output_dir/$srr_id";

        if (-d $results_dir) {
            $self->status_message("Found directory, skipping download: $results_dir");
        }
        else {
	    my $out = $fof . '.download.out';
	    my $err = $fof . '.download.err';


	    #### jmartin ... 100813
            ####my $cmd = "cd $tmp; $scripts_dir/get_SRA_runs.pl ascp $index_file $fof >$out 2>$err";
	    my $cmd = "cd $output_dir; $scripts_dir/get_SRA_runs.pl ascp $index_file $fof >$out 2>$err";

            Genome::Utility::FileSystem->shellcmd(
                cmd => $cmd,
                input_files => [$fof],
		output_files => [$out],
                output_directories => [$results_dir],
                skip_if_output_is_present => 1,
            );

	    my $out_content = Genome::Utility::FileSystem->read_file($out);
	    ####if ($out_content =~ /transferred .* SRA runs with ascp, (\d+) failures(s) detected/) {
	    if ($out_content =~ /transferred\s+.*\s+SRA\s+runs\s+with\s+ascp\,\s+(\d+)\s+failure\(s\)\s+detected/) {
		my $failures = $1;
		if ($failures == 0) {
		    $self->status_message("No failures from the download");
		}
		else {
		    $self->error_message("$failures failures downloading!  STDOUT is:\n$out_content\n");
		    die $self->error_message("$failures failures downloading!");
		}
	    }
	    else {
		$self->error_message("No completion line in the log file.  Content is: $out_content");
		die "No completion line in the log file?";
	    }
        }
    }

    return 1;
}

1;

