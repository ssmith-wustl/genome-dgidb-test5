package Genome::InstrumentData::Command::Import::HmpSraProcess;

use strict;
use warnings;
use Genome;
use Cwd;
use IO::File;
use File::Basename;

class Genome::InstrumentData::Command::Import::HmpSraProcess {
    is  => 'Command',
    has_input => [
	run_dir => {
	    is_optional => 1,
	    doc => 'path to directory containing SRR id folders',
	},
	list_of_srrs => {
	    is_optional => 1,
	    doc => 'file containing a single column list of SRR ids to process',
	},
	sra_samples => {
	    is_optional => 1,
	    doc => '2 column list of mappings of SRR ids to sample ids',
	},
	picard_dir => {
	    is_optional => 1,
	    doc => 'full path to directory containing Picard jar files (note: This path must include the updated EstimateLibraryComplexity that handles redundancy removal)',
	},
	tmp_dir => {
	    is_optional => 1,
	    doc => 'OPTIONAL - user defined path to tmp directory for picard (note: Picard uses a lot of tmp space, make sure this has enough space for your job)',
	},
    ],
    doc => 'de-duplicate and quality trim Illumina WGS runs downloaded from SRA',
};

sub execute {
    my $self = shift;


#___This line stops the perl debugger as though I'd set a break point in the GUI
    $DB::single = 1;


    my $scripts_dir = __FILE__;
    $scripts_dir =~ s/\.pm//;
    $self->status_message("Scripts are in: $scripts_dir");

    #Find current path to the script 'trimBWAstyle.usingBam.pl'
    my $current_dir = `pwd`;
    chomp ($current_dir);
    my $path_to_scripts_dir = $current_dir . "/" . $scripts_dir;

    #Run BROAD's processing script
    my $cmd;
    my $working_dir  = $self->run_dir;
    my $list_of_srrs = $self->list_of_srrs;
    my $list_of_srrs_FILENAME = basename($list_of_srrs);
    my $errfile = $working_dir . "/ReadProcessing." . $list_of_srrs_FILENAME . ".err";
    my $outfile = $working_dir . "/ReadProcessing." . $list_of_srrs_FILENAME . ".out";
    my $sra_samples  = $self->sra_samples;
    my $picard_dir   = $self->picard_dir;
#___Check for user defined tmp_dir...use generic /tmp dir if not user defined
    my $tmp_dir      = $self->tmp_dir;
    if ($tmp_dir) {
	unless (-d $tmp_dir) {
	    die "tmp_dir =>$tmp_dir<= not found\n";
	}
	$self->status_message("Using user defined tmp_dir at $tmp_dir");
    } else {
	$tmp_dir = Genome::Utility::FileSystem->create_temp_directory();
	$self->status_message("Autogenerated tmp_dir is at $tmp_dir");
    }

    #Set the $PATH env variable in perl
    my $path = $ENV{'PATH'} . ":" . $path_to_scripts_dir;

    #Note: I need to set the path to my scripts INSIDE the shell command
    $cmd = "cd $working_dir; export PATH=$path; process_runs.sh $list_of_srrs $sra_samples $picard_dir $tmp_dir > $outfile 2> $errfile";

    #$self->status_message("CMD=>$cmd<=\n");
    #$self->status_message("PWD=>$current_dir<=\n");

    Genome::Utility::FileSystem->shellcmd(
	cmd => $cmd,
	output_files => [$errfile,$outfile],
	);

    return 1;
}


#End package
1;
