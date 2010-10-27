
package Genome::Model::Tools::ViromeEvent::BlastX_Viral::InnerCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastX_Viral::InnerCheckOutput{
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

    my $input_file = $self->file_to_run;
    my $input_file_name = basename($input_file);

    $self->log_event("Checking Viral blastX run status for $input_file_name");

    my $blast_out_file = $input_file;
    $blast_out_file =~ s/fa$/tblastx_ViralGenome\.out/;
    my $blast_out_file_name = basename($blast_out_file);

    if (-s $blast_out_file) {
	my $tail = `tail -n 20 $blast_out_file`;
	if ($tail =~ /Matrix/) {
	    $self->log_event("Viral blastX already ran for $input_file_name");
	    return 1;
	}
    }

    $self->log_event("Running Viral blastX for $input_file_name");

#   my $blast_db = '/gscmnt/sata835/info/medseq/virome/blast_db2/viral/viral1.genomic.fna';
    my $blast_db = '/gscmnt/sata835/info/medseq/virome/blast_db/viral/viral.genomic.fna';
    my $cmd = 'blastall -p tblastx -e 0.1 -I T -i '.$input_file.' -o '.$blast_out_file.' -d '.$blast_db;
    if (system($cmd)) {
	$self->log_event("Viral blastX failed for $input_file_name");
	return;
    }

    $self->log_event("Viral blastX completed for $input_file_name");

    return 1;
}

1;

