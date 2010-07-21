
package Genome::Model::Tools::ViromeEvent::BlastHumanGenome::InnerCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastHumanGenome::InnerCheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
    #doesn't use fasta file or sample file -- refactor
    has =>
    [
        file_to_run => {
                            is => 'String',
                            doc => 'file to check and re-submit if necessary',
                            is_input => 1,

                        }
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
        checks file and resubmits if necessary 
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;
}

sub execute {
    my $self = shift;

    #IF ALL READS HAVE BEEN FILTERED OUT BY THIS POINT
    #$self->log_event("No further data to process") and return 1
    #	unless $self->file_to_run;

    my $input_file = $self->file_to_run;
    my $input_file_name = basename ($input_file);
    $self->log_event("Checking HG blastN run status for $input_file_name");

    my $blast_out_file = $input_file;

    $blast_out_file =~ s/\.fa$/\.HGblast.out/;
    my $blast_out_file_name = basename ($blast_out_file);

    if (-s $blast_out_file) {
	my $tail = `tail -n 50 $blast_out_file`;
	if ($tail =~ /Matrix/) {
	    $self->log_event("HG blastN already ran for $blast_out_file_name");
	    return 1;
	}
    }

    $self->log_event("Running HG blastN on $input_file_name");

    my $blast_db = '/gscmnt/sata835/info/medseq/virome/blast_db/human_genomic/2009_07_09.humna_genomic'; #TYPO!
    my $cmd = 'blastall -p blastn -e 1e-8 -I T -b 2 -i '.$input_file.' -o '.$blast_out_file.' -d '.$blast_db;

    if (system ($cmd)) {
	$self->log_event("HG blastN failed for $input_file_name");
	return;
    }

    $self->log_event("HG blast N completed for $input_file_name");

    return 1;
}

1;

