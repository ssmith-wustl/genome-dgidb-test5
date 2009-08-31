
package Genome::Model::Tools::ViromeEvent::BlastHumanGenome::OuterCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastHumanGenome::OuterCheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output=>[
        files_for_blast=> { is => 'ARRAY',  doc => 'array of files for blast n', is_optional => 1},
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
This script will check whether each HGblast.out file in a given directory 
has finished. If not, it will add to a list of files for resubmission (to be executed by InnerOuterCheckOutput). 

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
    $self->log_event("Outer Blast Human Genome check output entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $com;
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];
 
    my @files_for_blast;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        if ($name =~ /\.goodSeq_HGblast$/) 
        { # directory for blasting human genome with splited files
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $file (readdir SubDH) 
            {
	        if ($file =~ /\.goodSeq_file\d+\.fa$/) 
                { 
                    # masked unique sequences in splited files
		    my $inF_path = $full_path."/".$file;
                    push(@files_for_blast,$inF_path);
	        }
	    }
        }
    }
    $self->log_event("culled files:  " . join("\n", @files_for_blast));
    $self->files_for_blast(\@files_for_blast);

    $self->log_event("Outer Blast Human Genome check output completed");
    return 1;
}



1;

