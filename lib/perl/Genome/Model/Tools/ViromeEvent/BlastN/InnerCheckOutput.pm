
package Genome::Model::Tools::ViromeEvent::BlastN::InnerCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastN::InnerCheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
    #doesn't use fasta file or sample file -- refactor
    has =>
    [
        file_to_run => {
             is => 'String',  
            doc => 'files to rerun repeat masker', 
            is_input => 1,
        }
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
Checks whether blastn.out file has finished. If not, it will automatically resubmit the job. 

perl script <blast_file>
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute {
    my $self = shift;

    my $input_file = $self->file_to_run;
    my $input_file_name = basename($input_file);

    $self->log_event("Checking NT blastN run status for $input_file_name");

    my $blast_out_file = $input_file;
    $blast_out_file =~ s/fa$/blastn\.out/; #TODO - CAREFUL HERE
    my $blast_out_file_name = basename($blast_out_file);

    if (-s $blast_out_file) {
	my $tail = `tail -n 50 $blast_out_file`;
	if ($tail =~ /Matrix/) {
	    $self->log_event("NT blastN already ran for $input_file_name");
	    return 1;
	}
    }
    $self->log_event("Running NT blastN for $input_file_name");

    #my $blast_db = '/gscmnt/sata835/info/medseq/virome/blast_db/nt/2009_07_09.nt';
    my $blast_db = '/gscmnt/sata835/info/medseq/virome/blast_db/nt/nt';
    my $cmd = 'blastall -p blastn -e 1e-8 -I T -i '.$input_file.' -o '.$blast_out_file.' -d '.$blast_db;

    if (system ($cmd)) {
	$self->log_event("NT blastN failed for $input_file_name");
	return;
    }

    $self->log_event("NT blastN completed for $input_file_name");

    return 1;
}

1;

