package Genome::InstrumentData::Command::Import::HmpSraProcess;

use strict;
use warnings;
use Genome;
use Cwd;
use IO::File;

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
	    doc => 'path to tmp directory for picard (note: Picard uses a lot of tmp space, make sure this has enough space for your job)',
	},
    ],
    doc => 'de-duplicate and quality trim Illumina WGS runs downloaded from SRA',
};

sub execute {
    my $self = shift;

    my $scripts_dir = __FILE__;
    $scripts_dir =~ s/\.pm//;
    $self->status_message("Scripts are in: $scripts_dir");


    #Run BROAD's processing script
    my $cmd;
    my $working_dir  = $self->run_dir;
    my $errfile = $working_dir . "/ReadProcessing.err";
    my $outfile = $working_dir . "/ReadProcessing.out";
    my $list_of_srrs = $self->list_of_srrs;
    my $sra_samples  = $self->sra_samples;
    my $picard_dir   = $self->picard_dir;
    my $tmp_dir      = $self->tmp_dir;

    $cmd = "cd $working_dir; $scripts_dir/process_runs.sh $list_of_srrs $sra_samples $picard_dir $tmp_dir > $outfile 2> $errfile";

    Genome::Utility::FileSystem->shellcmd(
	cmd => $cmd,
	output_files => [$errfile,$outfile],
	);

    return 1;
}


#End package
1;
