
package Genome::Model::Tools::ViromeEvent::RepeatMasker::InnerCheckResult;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::RepeatMasker::InnerCheckResult{
    is => 'Genome::Model::Tools::ViromeEvent',
    has =>[
        file_to_run => {
             is => 'String',  
            doc => 'files to rerun repeat masker', 
            is_input => 1,
        }
    ],
};

sub help_brief {
    return "module to make system call for repeat masker (decoupled for parallelization)";
}

sub help_synopsis {
    return <<"EOS"
    
EOS
}

sub help_detail {
    return <<"EOS"
    Accepts a file for re-running repeat masker.  Assumes full path is included.  
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
    my $file = $self->file_to_run;

    $self->log_event("Inner check result entered for $file");

    # run RepeatMasker
    my $com = "/gsc/var/tmp/virome/scripts/scripts2/RepeatMasker  " . $file . "\n"; #using gzhao's libraries for repeat masker

    $self->log_event("re-running repeat masker:  '$com'");
    system($com);

    $self->log_event("Inner check result completed for $file");
    return 1;
}

1;



