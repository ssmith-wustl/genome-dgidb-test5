
package Genome::Model::Tools::ViromeEvent::BlastX_NT::CheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastX_NT::CheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
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
    $self->log_event("Blast X NT check output entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];
    my $directory_job_file = $dir."/".$lib_name.".job";

    my $allFinished = 1;
    my $have_input_file = 0;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my $matches = 0;
    foreach my $name (readdir DH) 
    {
        if ($name =~ /BNFiltered_TBLASTX_nt$/) 
        { # directory for tblastx with splited files

            $matches++;
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $file (readdir SubDH) 
            { 
	        if ($file =~ /\.BNFiltered\.fa_file\d+\.fa$/) 
                { # tblastx input file
		    $have_input_file = 1;
		    my $resubmit = 0;
    		    my $temp = substr($file, 0, -3);
		    my $job_file=$full_path."/".$temp.".job";
		    my $blast_out_file = $full_path."/".$temp.".tblastx.out";
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
		        $allFinished = 0;
		        print $blast_out_file, " does not exist or finish! resubmitted\n";
		    
		        my $temp = substr($file, 0, -3);
		        my $str = $full_path."/".$temp;

		        my $blast_param = '-d /gscmnt/sata835/info/medseq/virome/blast_db/nt/2009_07_09.nt';
		        my $com = 'blastall -p tblastx  -i '.$str.'.fa -o '.$str.'.tblastx.out -e 1e-2 -I T '.$blast_param;
                        $self->log_event("calling $com");
                        system($com);
		        #use PP::LSF;
		        #my $job = PP::LSF->run ( pp_type => 'lsf',
			#		     command => $com,
			#		     J => 'NTBlastX',
			#		     q => 'long',
                        #                     R => "'select[type==LINUX64] span[hosts=1]'",);
		        #if (! $job) 
                        #{
			#    die("Failed to submit lsf job:\n $com\n");
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
	    $self->log_event("All tblastx against nt are finished!\n");
        }
    }

    $self->log_event("Blast X NT check output completed with $matches matches");
    return 1;
}



1;

