
package Genome::Model::Tools::ViromeEvent::BlastN::OuterCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastN::OuterCheckOutput{
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
This culls a list of files in the HGfiltered_BLASTN subdirectory to pass to InnerCheckOutput

<dir> = full path to the directory holding files for a sample
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

    $self->log_event("Checking files to run NT blastN for $sample_name");

    my $nt_blast_dir = $dir.'/'.$sample_name.'.HGfiltered_BLASTN';
    unless (-d $nt_blast_dir) {
	$self->log_event("Failed to find NT blast directory for $sample_name");
	return;
    }

    my @fa_files = glob("$nt_blast_dir/*fa");
    unless (scalar @fa_files > 0) {
	#IF PREVIOUS EVENT FILTERED FILE EXISTS WITH SIZE
	if (-s $dir.'/'.$sample_name.'.HGfiltered.fa' > 0) {
	    $self->log_event("Failed to create fasta files for NT blastN for $sample_name");
	    return;
	}
	elsif (-e $dir.'/'.$sample_name.'.HGfiltered.fa') {
	    $self->log_event("No further data available for NT blastN for $sample_name");
	    $self->files_for_blast([]);
	    return 1;
	}
	else {
	    $self->log_event("No fasta files found to run NT blastN for $sample_name");
	    return;
	}
    }

    my @files_for_blast;

    foreach my $fa (@fa_files) {
	next unless $fa =~/file\d+\.fa$/; #INPUT FILES IGNORING FILTERED FASTA FILES
	push @files_for_blast, $fa;
    }

    unless (scalar @files_for_blast > 0) {
	$self->log_event("Failed to find or no data available to NT blastN for $sample_name");
	return;
    }

    $self->files_for_blast(\@files_for_blast);
    
    $self->log_event("Finished checking files to run NT blastN for $sample_name");
    return 1;
}

1;

