
package Genome::Model::Tools::ViromeEvent::BlastX_Viral::CheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastX_Viral::CheckOutput{
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
    $self->log_event("Blast X viral check output entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];

    my $allFinished = 1;
    my $have_input_file = 0;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my $matches = 0;
    foreach my $name (readdir DH) 
    {
        if ($name =~ /TBXNTFiltered_TBLASTX_ViralGenome$/) 
        { # directory for tblastx viral genome with splited files
            $matches++;
	    my $full_path = $dir."/".$name;
    	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $file (readdir SubDH) 
            { 
	        if ($file =~ /\.TBXNTFiltered\.fa_file\d+\.fa$/) 
                { # masked unique sequences in splited files
		    $have_input_file = 1;
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
		        $allFinished = 0;
		        $self->log_event($blast_out_file, " does not exist or finish! resubmitted\n");
		    
		        my $temp = substr($file, 0, -3);
		        my $str = $full_path."/".$temp;
		        my $blast_param = '-d /gscmnt/sata835/info/medseq/virome/blast_db/viral/2009_07_09.viral.genomic.fna';
		    
		        my $com = 'blastall -p tblastx  -i '.$str.'.fa -o '.$str.'.tblastx_ViralGenome.out -e 0.1 -I T '.$blast_param;
                        $self->log_event("calling $com");
                        system($com);
		        #use PP::LSF;
		        #my $job = PP::LSF->run ( pp_type => 'lsf',
			#		     command => $com,
			#		     J => 'VrBlastX',
			#		     q => 'long',
                        #                     R => "'select[type==LINUX64] span[hosts=1]'",);
		        #if (! $job) {
			#    dice("Failed to submit job:\n $com\n");
		        #}
		    
		    }
	        }
	    }
        }
    }

#close BigJobFile;

    if ($have_input_file) 
    {
        if ($allFinished ) 
        {
	    $self->log_event("All tblastx against Viral Genome are finished!\n");
	    return 0;
        }
    }

    $self->log_event("Blast X viral check output completed with $matches matches");
    return 1;
}


1;

