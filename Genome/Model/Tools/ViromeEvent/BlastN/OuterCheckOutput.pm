
package Genome::Model::Tools::ViromeEvent::BlastN::OuterCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastN::OuterCheckOutput{
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
This culls a list of files in the HGfiltered_BLASTN subdirectory to pass to InnerCheckOutput

<dir> = full path to the directory holding files for a sample
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
    $self->log_event("Outer Blast N check output entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];

    my @files_for_blast;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        if ($name =~ /\.HGfiltered_BLASTN$/) 
        { # directory for blastn with splited files
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
            #$self->blast_path(\$full_path);
	    foreach my $file (readdir SubDH) 
            {
	        if ($file =~ /\.HGfiltered\.fa_file\d+\.fa$/)
                { 
		    my $inF_path = $full_path."/".$file;
                    push(@files_for_blast, $inF_path);
                }
            } 
        }
    }
    $self->files_for_blast(\@files_for_blast);
    
    $self->log_event("files for blast:\n" . join("\n", @files_for_blast));

    $self->log_event("Outer Blast Human N check output completed");
    return 1;
}


1;

