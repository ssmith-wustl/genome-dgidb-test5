
package Genome::Model::Tools::ViromeEvent::BlastHumanGenome::OuterCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastHumanGenome::OuterCheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output=>[
        files_for_blast=> { is => 'ARRAY',  doc => 'array of files for blast n', is_optional => 1},
    ],
};

sub help_brief {
    return "gzhao's Blast Human Genome check output";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will check whether each HGblast.out file in a given directory 
has finished. If not, it will add to a list of files for resubmission (to be executed by InnerOuterCheckOutput). 

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
    my $sample_name = basename ($dir);

    $self->log_event("Checking files to run HG blast for $sample_name");

    my $hg_blast_dir = $dir.'/'.$sample_name.'.fa.cdhit_out.masked.goodSeq_HGblast';
    unless (-d $hg_blast_dir) {
	$self->log_event("Failed to find HG blast directory for $sample_name");
	return;
    }

    my @fa_files = glob ("$hg_blast_dir/$sample_name*fa");
    unless (scalar @fa_files > 0) {
	#IF PREVIOUS STEP FILTERED FILE EXISTS WITH SIZE
	if (-s $dir.'/'.$sample_name.'.fa.cdhit_out.masked.goodSeq' > 0) {
	    $self->log_event("Failed to create fasta file for HG blast for $sample_name");
	    return;
	}
	#IF ALL READS HAVE BEEN FILTERED OUT AT PREVIOUS REPEATMASKER STEP
	elsif (-e $dir.'/'.$sample_name.'.fa.cdhit_out.masked.goodSeq') {
	    $self->log_event("No further reads available for HG blast for $sample_name");
	    #GIVE IT A BLANK ARRYREF TO CONTINUE TO NEXT STEP
	    $self->files_for_blast([]);
	    return 1;
	}
	#SHOULD NEVER GET TO THIS POINT
	else {
	    $self->log_event("Failed previous step repeatMasker for $sample_name");
	    return;
	}
    }

    my @files_for_blast;

    foreach my $file (@fa_files) {
	next if $file =~ /\.HGfiltered\.fa$/; #PRODUCT OF BLAST ALREADY RAN
	push @files_for_blast, $file;
    }

    unless (scalar @files_for_blast > 0) {
	$self->log_event("Failed to find or no more data available for HG blastN");
	return;
    }

    $self->files_for_blast(\@files_for_blast);

    $self->log_event("Finished checking files to run HG blast for $sample_name");

    return 1;
}



1;

