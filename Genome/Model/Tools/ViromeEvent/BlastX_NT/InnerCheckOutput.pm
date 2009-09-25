
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

sub execute
{
    my $self = shift;
    my $file = $self->file_to_run;
    my $full_path = dirname($file);
    my $file_name = basename($file);
    my $com;

    $self->log_event("inner check entered for $file_name");

		    my $resubmit = 0;
    		    my $temp = substr($file, 0, -3);
		    my $job_file=$full_path."/".$temp.".job";
#		    my $blast_out_file = $full_path."/".$temp.".tblastx.out";
		    my $blast_out_file = $temp.".tblastx.out";
		    if (!(-s $blast_out_file)) 
                    {
		        $resubmit = 1;
		    }
		    else 
                    { # has the output, check whether finished
		        my $com = "tail -n 50 $blast_out_file";
		        my $output = qx/$com/;
		        if (!($output =~ /Matrix:/)) 
                        {
			    $resubmit = 1;
		        }
		    }
		
		    if ($resubmit) 
                    {
		        $self->log_event($blast_out_file . " does not exist or finish! resubmitted");
		    
		        my $temp = substr($file, 0, -3);
                        #my $str = $full_path."/".$temp;	
                        my $str = $temp;

		        my $blast_param = '-d /gscmnt/sata835/info/medseq/virome/blast_db/nt/2009_07_09.nt';
		        my $com = 'blastall -p tblastx  -i '.$str.'.fa -o '.$str.'.tblastx.out -e 1e-2 -I T '.$blast_param;
                        $self->log_event("calling $com");
                        system($com);
		    }
       $self->log_event("inner check completed for $file_name");
    return 1;
}



1;

