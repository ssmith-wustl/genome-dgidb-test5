
package Genome::Model::Tools::ViromeEvent::RepeatMasker::CheckResult;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::RepeatMasker::CheckResult{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Repeat Masker check result";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will check the result of RepeatMasker which
should generate .masked file in the given directory.

perl script <dir>
<dir> = full path to the directory of a sample library
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
    my $dir = $self->dir;

    $self->log_event("Repeat Masker check result entered for $dir");

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];
    my $directory_job_file = $dir."/".$lib_name.".job";

    my $allFinished = 1;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    $self->log_event("step 0 $dir opened");
    foreach my $name (readdir DH) 
    {
        $self->log_event("step 1 processing $name");
        if ($name =~ /.cdhit_out_RepeatMasker$/) 
        { # RepeatMasker directory
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
            $self->log_event("step 2 $name matches cdhit_out_RepeatMasker opening $full_path");
	    foreach my $file (readdir SubDH) 
            {
                $self->log_event("step 3 processing $file");
	        if ($file =~ /\.cdhit_out_file\d+\.fa$/) 
                {
                    $self->log_event("step 4 $file matches cdhit_out_file");
		    my $have_masked = 0;
		    my $have_other = 0;

		    my $tempfile = $full_path."/".$file.".out";
		    if (-e $tempfile) 
                    {
		        $have_other = 1;
                        $self->log_event("step 4.1 $tempfile exists");
		    }
                    else
                    {
                        $self->log_event("step 4.1 $tempfile doesn't exist");
                    }

		    $tempfile = $full_path."/".$file.".masked";
		    if (-e $tempfile) 
                    {
		        $have_masked = 1;
                        $self->log_event("step 4.2 $tempfile exists");
		    }
                    else
                    {
                        $self->log_event("step 4.2 $tempfile doesn't exist");
                    }
		
		    if (!$have_masked) 
                    {
		        if (!$have_other) 
                        {
			    $allFinished = 0;
			    # rerun RepeatMasker
			    my $name = $file;
			    $name = substr($name, 0, -3);
			    my $inF_path = $full_path."/".$file;

		            # run RepeatMasker
			    #my $com = "RepeatMasker  ".$inF_path."\n";
			    my $com = "/gsc/var/tmp/virome/scripts/scripts2/RepeatMasker  ".$inF_path."\n"; #using gzhao's libraries for repeat masker

                            $self->log_event("step 5 re-running repeat masker:  '$com'");
                            system($com);
			    #use PP::LSF;
			    #my $job = PP::LSF->run ( pp_type => 'lsf',
				#		    command => $com,
				#		    J => 'RptMskr',
				#		    q => 'long',
			        #                    R => "'select[type==LINUX64] span[hosts=1]'", );
			   #if (! $job) 
                           #{
                           #     $self->log_event("step 6 failed to submit $com");
			   #     print "Failed to submit job:\n $com\n";
			   #     die("Failed to submit job:\n $com\n");
			   # }
			
		        }
					# sometimes repeatmasker do not find any repeat in 
					# input files, in these cases no .masked file will 
					# be generated.
		        else 
                        { 
                            $self->log_event("step 5 running original repeat masker");
			    my $original = $full_path."/".$file;
			    my $target = $original.".masked";
			    my $com = "cp $original $target \n";
			    system ( $com );
		        }
		    }
	        }
	    }
        }
    }

    #close BigJobFile;

    if ($allFinished) 
    {
	print "RepeatMasking all finished.\n";
	return 0;
    }

    return 0;

    $self->log_event("RepeatMasker check result completed");
    return 1;
}

1;

