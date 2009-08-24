
package Genome::Model::Tools::ViromeEvent::BlastHumanGenome::CheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastHumanGenome::CheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
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
    $self->log_event("Blast Human Genome check output entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $com;
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];
 
    my $allFinished = 1;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    $self->log_event("step 0:  looking in $dir");
    foreach my $name (readdir DH) 
    {
        $self->log_event ("step 1:  checking $name");
        if ($name =~ /\.goodSeq_HGblast$/) 
        { # directory for blasting human genome with splited files
            $self->log_event("step 2:  $name has HGblast");
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
            $self->log_event("running check output on $full_path");
	    foreach my $file (readdir SubDH) 
            {
                $self->log_event("opened $file"); 
	        if ($file =~ /\.goodSeq_file\d+\.fa$/) 
                { # masked unique sequences in splited files
		    my $resubmit = 0;
		    my $name = $file;
		    $name = substr($name, 0, -3);

		    my $blast_out_file = $full_path."/".$name.".HGblast.out";
		    if (!(-s $blast_out_file)) 
                    {
		        $resubmit = 1;
		        $allFinished = 0;
		    }
		    else 
                    { # has the output, check whether finished
		        $com = "tail -n 50 $blast_out_file";
		        my $output = qx/$com/; 
		        if (!($output =~ /Matrix:/)) 
                        {
			    $resubmit = 1;
			    $allFinished = 0;
		        }
		    }
			
		    if ($resubmit) 
                    {
		        my $str = $full_path."/".$name;
                        $self->log_event("resubmitting $str");
		        # use -b 2 to print only alignments for two hits

		        my $blast_param = '-d /gscmnt/sata835/info/medseq/virome/blast_db/human_genomic/2009_07_09.humna_genomic';
		        $com = 'blastall -p blastn -e 1e-8 -I T -b 2 -i '.$str.'.fa -o '.$str.'.HGblast.out '.$blast_param;
                        system($com);
		        #use PP::LSF;
		        #my $job = PP::LSF->run ( pp_type => 'lsf',
			#		     command => $com,
			#		     J => 'HGBlastN',
			#		     q => 'short',
			#                     R => "'select[type==LINUX64] span[hosts=1]'",);
		        #if (! $job) 
                        #{
			#    die("Failed LSF submit job for $com\n");
		        #}
		    }
	        }
	    }
        }
    }

    #close BigJobFile;

    if ($allFinished) 
    {
	$self->log_event("All blast against human genome are finished!\n");
        return 0;
    }


    $self->log_event("Blast Human Genome check output completed");
    return 1;
}



1;

