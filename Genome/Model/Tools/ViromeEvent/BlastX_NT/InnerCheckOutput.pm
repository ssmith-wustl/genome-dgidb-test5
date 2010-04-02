
package Genome::Model::Tools::ViromeEvent::BlastX_NT::InnerCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastX_NT::InnerCheckOutput{
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
    return "gzhao's Blast X nt check output";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
checks whether each tblastx.out file in the 
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

    my $input_file = $self->file_to_run;
    my $input_file_name = basename($input_file);

    $self->log_event("Checking NT blastX run status for $input_file_name");

    my $blast_out_file = $input_file;
    $blast_out_file =~ s/fa$/tblastx\.out/;
    my $blast_out_file_name = basename($blast_out_file);

    if (-s $blast_out_file) {
	my $tail = `tail -n 50 $blast_out_file`;
	if ($tail =~ /Matrix/) {
	    $self->log_event("NT blastX already ran for $input_file_name");
	    return 1;
	}
    }

    $self->log_event("Running NT blastX for $input_file_name");

#   my $blast_db = '/gscmnt/sata835/info/medseq/virome/blast_db/nt/2009_07_09.nt';
    my $blast_db = '/gscmnt/sata835/info/medseq/virome/blast_db/nt/2010_04_01.nt';

    my $cmd = 'blastall -p tblastx -e 1e-2 -I T -i '.$input_file.' -o '.$blast_out_file.' -d '.$blast_db;

    if (system($cmd)) {
	$self->log_event("NT blastX failed for $input_file_name");
	return;
    }

    $self->log_event("NT blastX completed for $input_file_name");
    return 1;
};

1;


