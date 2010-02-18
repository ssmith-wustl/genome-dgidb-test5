
package Genome::Model::Tools::ViromeEvent::BlastX_NT::OuterCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastX_NT::OuterCheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output=>[
        files_for_blast=> { is => 'ARRAY',  doc => 'array of files for blast n', is_optional => 1},
    ],
};

sub help_brief {
    return "gzhao's Blast X nt check output";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This culls a list of files in the BNfiltered_TBLASTX subdirectory to pass to InnerCheckOutput
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

    $self->log_event("Preparing to run NT blastX for $sample_name");
    
    my $blast_dir = $dir.'/'.$sample_name.'.BNFiltered_TBLASTX_nt';
    unless (-d $blast_dir) {
	$self->log_event("Failed to find NT blastX directory for $sample_name");
	return;
    }

    my @fa_files = glob("$blast_dir/*fa");
    unless (scalar @fa_files > 0) {
	if (-s $dir.'/'.$sample_name.'.BNFiltered.fa' > 0) {
	    $self->log_event("Failed to create fasta file for NT blastX for $sample_name");
	    return;
	}
	elsif (-e $dir.'/'.$sample_name.'.BNFiltered.fa') {
	    $self->log_event("No further data to process NT blastX for $sample_name");
	    $self->files_for_blast([]);
	    return 1;
	}
	$self->log_event("No fasta files found to run NT blastX for $sample_name");
	return;
    }
    
    my @files_for_blast;

    foreach my $fa (@fa_files) {
	next unless $fa =~ /file\d+\.fa$/;
	push @files_for_blast, $fa;
    }

    unless (scalar @files_for_blast > 0) {
	$self->log_event("Failed to find or no data available to run NT blastX for $sample_name");
	return;
    }

    $self->files_for_blast(\@files_for_blast);

    $self->log_event("Finished checking files to run NT blastX for $sample_name");

    return 1;
}

1;

