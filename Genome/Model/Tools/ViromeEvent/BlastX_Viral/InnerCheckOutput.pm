
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

sub execute
{
    my $self = shift;
    my $file = $self->file_to_run;
    my $full_path = dirname($file);
    my $file_name = basename($file);
    my $com;


    $self->log_event("inner check output entered for $file_name");

		    my $resubmit = 0;
		    my $temp = substr($file, 0, -3);
		    my $job_file=$full_path."/".$temp.".job";
		    my $blast_out_file = $full_path."/".$temp.".tblastx_ViralGenome.out";
		    if (!(-e $blast_out_file)) 
                    {
		        $resubmit = 1;
		    }
		    else 
                    { # has the output, check whether finished
                        $self->log_event("have $blast_out_file");
		        my $com = "tail -20 $blast_out_file";
		        my $output = qx/$com/; 
		        if (!($output =~ /Matrix:/)) 
                        {
			    $resubmit = 1;
		        }
		    }
		
		    if ($resubmit) 
                    {
		        $self->log_event($blast_out_file, " does not exist or finish! resubmitted\n");
		    
		        my $temp = substr($file, 0, -3);
		        my $str = $full_path."/".$temp;
		        my $blast_param = '-d /gscmnt/sata835/info/medseq/virome/blast_db/viral/2009_07_09.viral.genomic.fna';
		    
		        my $com = 'blastall -p tblastx  -i '.$str.'.fa -o '.$str.'.tblastx_ViralGenome.out -e 0.1 -I T '.$blast_param;
                        $self->log_event("calling $com");
                        system($com);
		    }

    $self->log_event("inner check output completed for $file_name");
    return 1;
}


1;

