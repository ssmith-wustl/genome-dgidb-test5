
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
		
#		    my $blast_out_file = $full_path."/".$temp.".blastn.out";
		    my $blast_out_file = $temp.".blastn.out";
		    if (!(-s $blast_out_file)) 
                    {
                        $self->log_event("\t no size for $blast_out_file");
		        $resubmit = 1;
		    }
		    else 
                    {# has the output, check whether finished
		        my $com = "tail -n 50 $blast_out_file";
		        my $output = qx/$com/;
		        if (!($output =~ /Matrix:/)) 
                        {
			    $resubmit = 1;
		        }
		    }

		    if ($resubmit) 
                    {
                        my $str = $temp;	
		        my $blast_param = '-d /gscmnt/sata835/info/medseq/virome/blast_db/nt/2009_07_09.nt';
		        my $com = 'blastall -p blastn -e 1e-8 -I T -i '.$str.'.fa -o '.$str.'.blastn.out '.$blast_param;
		        $self->log_event("resubmitting $com"); 
                        system($com);
		    }
    $self->log_event("inner check completed for $file_name");
    return 1;
}


1;

