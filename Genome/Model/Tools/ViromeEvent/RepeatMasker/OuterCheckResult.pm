
package Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;
use File::Copy;

class Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output => [
        files_to_run=> { is => 'ARRAY',  doc => 'array of files for repeat masker', is_optional => 1},
    ]
};

sub help_brief {
    return "gzhao's Repeat Masker check result";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will check the result of RepeatMasker which
should generate .masked file in the given directory.

perl script <dir>
<dir> = full path to the directory of a sample library
               without last "/"
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute
{
    my $self = shift;

    my $dir = $self->dir;
    my $sample_name = basename ($dir);

    $self->log_event("Checking files to run repeat masker for sample: $sample_name");

    my $repeat_masker_dir = $dir.'/'.$sample_name.'.fa.cdhit_out_RepeatMasker';
    unless (-d $repeat_masker_dir) {
	$self->log_event("Failed to find repeat masker dir for sample: $sample_name");
	return;
    }

    my @fastas = glob ("$repeat_masker_dir/$sample_name*.fa");
    unless (scalar @fastas > 0) {
	$self->log_event("No input fastas for repeat masker run found for sample: $sample_name");
	return;
    }

    my @files_to_run;
    foreach my $file (@fastas) {
	my $out_file = $file.'.out';
	my $mask_file = $file.'.masked';
	if (! -s $out_file && ! -s $mask_file) {
	    #RUN REPEAT MASKER
	    push @files_to_run, $file;
	}
	elsif (! -s $mask_file) {
	    #REPEAT MASKER RAN WITH NO REPEATS
	    #COPY THE ORIGINAL FASTA TO .MASKED
	    copy $file, $mask_file;
	}
	else {
	    #REPEAT MASKER RAN
	    next;
	}
    }

    $self->files_to_run(\@files_to_run);
    $self->log_event("Completed check to run repeat masker for sample: $sample_name");

    return 1;
}


1

