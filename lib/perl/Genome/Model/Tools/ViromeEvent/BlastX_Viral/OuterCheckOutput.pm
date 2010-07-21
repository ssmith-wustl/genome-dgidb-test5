
package Genome::Model::Tools::ViromeEvent::BlastX_Viral::OuterCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastX_Viral::OuterCheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output=>[
        files_for_blast=> { is => 'ARRAY',  doc => 'array of files for blast n', is_optional => 1},
    ],
};

sub help_brief {
    return "gzhao's Blast N check output";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will check whether each tblastx.out file in the 
BNfiltered_TBLASTX subdirectory of a given directory 
has finished. If not, it will automatically resubmit the job. 

perl script <sample dir>
<sample dir> = full path to the directory holding files for a sample
               without last "/"
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute {
    my $self = shift;

    my $dir = $self->dir;
    my $sample_name = basename($dir);

    $self->log_event("Preparing to run Viral NT blastX for $sample_name");

    my $blast_dir = $dir.'/'.$sample_name.'.TBXNTFiltered_TBLASTX_ViralGenome';
    unless (-d $blast_dir) {
	$self->log_event("Failed to find Viral blastX directory for $sample_name");
	return;
    }

    my @fa_files = glob("$blast_dir/*fa");
    unless (scalar @fa_files > 0) {
	if (-s $dir.'/'.$sample_name.'.TBXNTFiltered.fa' > 0) {
	    $self->log_event("Failed to create fasta files for Viral BlastX for $sample_name");
	    return;
	}
	elsif (-e $dir.'/'.$sample_name.'.TBXNTFiltered.fa') {
	    $self->log_event("No further data available to process Viral BlastX for $sample_name");
	    $self->files_for_blast([]);
	    return 1;
	}
	$self->log_event("No fasta files found to run Viral blastX for $sample_name");
	return;
    }

    my @files_for_blast;

    foreach my $fa (@fa_files) {
	next unless $fa =~ /file\d+\.fa$/;
	push @files_for_blast, $fa;
    }

    unless (scalar @files_for_blast > 0) {
	$self->log_event("Failed to find or no data available to run Viral blastX for $sample_name");
	return;
    }

    $self->files_for_blast(\@files_for_blast);

    $self->log_event("Finished checking files to run Viral blastX for $sample_name");

    return 1;
}

1;

