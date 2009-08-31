
package Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output => [
        files_to_run=> { is => 'ARRAY',  doc => 'array of files for repeat masker', is_optional => 1},
    ]
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

    $self->log_event("Outer check result entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];
    my $directory_job_file = $dir."/".$lib_name.".job";

    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my @files_to_run;
    foreach my $name (readdir DH) 
    {
        if ($name =~ /.cdhit_out_RepeatMasker$/) 
        { # RepeatMasker directory
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
            $self->log_event("step 2 $name matches cdhit_out_RepeatMasker opening $full_path");
	    foreach my $file (readdir SubDH) 
            {
	        if ($file =~ /\.cdhit_out_file\d+\.fa$/) 
                {
		    my $have_masked = 0;
		    my $have_other = 0;

		    my $tempfile = $full_path."/".$file.".out";
		    if (-e $tempfile) 
                    {
		        $have_other = 1;
		    }

		    $tempfile = $full_path."/".$file.".masked";
		    if (-e $tempfile) 
                    {
		        $have_masked = 1;
		    }
		
		    if (!$have_masked) 
                    {
		        if (!$have_other) 
                        {
			    my $inF_path = $full_path."/".$file;
                            $self->log_event("pushing $inF_path");
                            push(@files_to_run, $inF_path);

                            # sometimes repeatmasker do not find any repeat in 
		            # input files, in these cases no .masked file will 
			    # be generated.
                        }
		        else 
                        { 
                            $self->log_event("running original repeat masker on $file");
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
    $self->log_event("files to run:  " . join("\n", @files_to_run)); 
    $self->files_to_run(\@files_to_run);

    $self->log_event("Outer check result completed");
    return 1;
}

1;

