
package Genome::Model::Tools::ViromeEvent::CDHIT::RemoveFile;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::CDHIT::RemoveFile{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    "skeleton for gzhao's virome script"
}

sub help_synopsis {
    return <<"EOS"

wrapper for script sequence to be utilized by workflow
EOS
}

sub help_detail {
    return <<"EOS"

wrapper for script sequence to be utilized by workflow

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

    opendir(DH, $dir) or die "Cannot open dir $dir!\n";
    foreach my $file (readdir DH) 
    { 
	if ($file =~ /\.bak\.clstr$/) 
        {
		my $tempfile = $dir."/".$file;
		if (-s $tempfile) 
                {
		    print "Removing $tempfile from $dir\n";
		}
		unlink $tempfile;
	}
    }
    $self->log_event("CDHIT Remove File complete for $dir");
    return 1;
}

1;

sub sub_command_sort_position { 7 }
