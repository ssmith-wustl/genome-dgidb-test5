
package Genome::Model::Tools::ViromeEvent::CDHIT::RemoveFile;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

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

#THIS COULD BE DONE IN CHECKRESULT MODULE
#SUBMIT THIS TO SHORT QUEUE
sub execute {
    my $self = shift;
    my $dir = $self->dir;
    my $sample_name = basename($dir);
    foreach (glob ("$dir/*.bak.clstr")) {
	unlink $_;
    }
    
    $self->log_event("Removed temp files for sample: $sample_name");
    return 1;
}

1;

sub sub_command_sort_position { 7 }
