
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

sub execute
{
    my $self = shift;
    my $file = $self->file_to_run;
    $self->log_event("inner check for $file");
    my $full_path = dirname($file);
    my $file_name = basename($file);
    my $com;

		    my $resubmit = 0;
		    my $name = substr($file_name, 0, -3);

		    my $blast_out_file = $full_path."/".$name.".HGblast.out";
		    if (!(-s $blast_out_file)) 
                    {
		        $resubmit = 1;
		    }
		    else 
                    { # has the output, check whether finished
		        $com = "tail -n 50 $blast_out_file";
		        my $output = qx/$com/; 
		        if (!($output =~ /Matrix:/)) 
                        {
			    $resubmit = 1;
		        }
		    }
			
		    if ($resubmit) 
                    {
		        my $str = $full_path."/".$name;
		        # use -b 2 to print only alignments for two hits

		        my $blast_param = '-d /gscmnt/sata835/info/medseq/virome/blast_db/human_genomic/2009_07_09.humna_genomic';
		        $com = 'blastall -p blastn -e 1e-8 -I T -b 2 -i '.$str.'.fa -o '.$str.'.HGblast.out '.$blast_param;
                        $self->log_event("resubmitting $com");
                        system($com);
		    }
    $self->log_event("inner check completed");
    return 1;
}



1;

