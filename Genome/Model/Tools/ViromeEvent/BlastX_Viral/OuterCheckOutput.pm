
package Genome::Model::Tools::ViromeEvent::BlastX_Viral::OuterCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastX_Viral::OuterCheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output=>[
        files_for_blast=> { is => 'ARRAY',  doc => 'array of files for blast n', is_optional => 1},
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
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];
    $self->log_event("Outer BlastX Viral entered for $lib_name");

    my $allFinished = 1;
    my $have_input_file = 0;
    my @files_for_blast;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        if ($name =~ /TBXNTFiltered_TBLASTX_ViralGenome$/) 
        { # directory for tblastx viral genome with splited files
	    my $full_path = $dir."/".$name;
    	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $file (readdir SubDH) 
            { 
	        if ($file =~ /\.TBXNTFiltered\.fa_file\d+\.fa$/) 
                { # masked unique sequences in splited files
		    my $inF_path = $full_path."/".$file;
                    $self->log_event("pushing $file in files for blastx viral");
                    push(@files_for_blast, $inF_path);
                }
	    }
        }
    }
    $self->files_for_blast(\@files_for_blast);

    $self->log_event("Outer BlastX Viral completed for $lib_name");
    return 1;
}


1;

