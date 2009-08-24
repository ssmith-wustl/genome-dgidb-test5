
package Genome::Model::Tools::ViromeEvent::BlastN::CheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastN::CheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
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
This script will check whether each blastn.out file in the 
HGfiltered_BLASTN subdirectory of a given directory 
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
    $self->log_event("Blast N check output entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];

    my $allFinished = 1;
    my $matches = 0;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        if ($name =~ /\.HGfiltered_BLASTN$/) 
        { # directory for blastn with splited files
            $matches++;
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $file (readdir SubDH) 
            { 
	        if ($file =~ /\.HGfiltered\.fa_file\d+\.fa$/) 
                { # masked unique sequences in splited files
    		    my $resubmit = 0;
		    my $temp = substr($file, 0, -3);
		
		    my $blast_out_file = $full_path."/".$temp.".blastn.out";
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
		        $allFinished = 0;
		        my $str = $full_path."/".$temp;	
		    
		        my $blast_param = '-d /gscmnt/sata835/info/medseq/virome/blast_db/nt/2009_07_09.nt';
		        my $com = 'blastall -p blastn -e 1e-8 -I T -i '.$str.'.fa -o '.$str.'.blastn.out '.$blast_param;
                        
                        $self->log_event("running $com");
                        system($com);
		        #use PP::LSF;
		        #my $job = PP::LSF->run ( pp_type => 'lsf',
			#		     command => $com,
			#		     J => 'NTBlastN',
			#		     q => 'long',
                        #                     R => "'select[type==LINUX64] span[hosts=1]'",);
		        #if (! $job) 
                        #{
			#    $self->log_event("Failed to submit lsf job: $com");
                        #    die("Failed to submit lsf job: $com");
		        #}

		    }
	        }
	    }
        }
    }

    #close BigJobFile;

    if ($allFinished) 
    {
        $self->log_event("All blastn against nt are finished!");
    }

    $self->log_event("Blast Human N check output completed with $matches matches");
    return 1;
}


1;

