
package Genome::Model::Tools::ViromeEvent::BlastX_NT::OuterCheckOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastX_NT::OuterCheckOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output=>[
        files_for_blast=> { is => 'ARRAY',  doc => 'array of files for blast n', is_optional => 1},
    ],
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
This culls a list of files in the BNfiltered_TBLASTX subdirectory to pass to InnerCheckOutput
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
    my $directory_job_file = $dir."/".$lib_name.".job";
    $self->log_event("Blast X NT check output entered for $lib_name");

    my @files_for_blast;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        if ($name =~ /BNFiltered_TBLASTX_nt$/) 
        { # directory for tblastx with splited files

	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $file (readdir SubDH) 
            { 
	        if ($file =~ /\.BNFiltered\.fa_file\d+\.fa$/) 
                { # tblastx input file
		    my $inF_path = $full_path."/".$file;
                    push(@files_for_blast, $inF_path);
	        }
	    }
       } 
    }
    $self->files_for_blast(\@files_for_blast);

    $self->log_event("Blast X NT check output completed for $lib_name");
    return 1;
}



1;

