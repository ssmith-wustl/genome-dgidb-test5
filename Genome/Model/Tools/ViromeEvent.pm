
package Genome::Model::Tools::ViromeEvent;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent{
    is => 'Command',
    is_abstract => 1,
    has =>
    [

             dir        => {
                                doc => 'directory of inputs',
                                is => 'String',
                                is_input => 1,
                            },            
    ],
    has_output => [
        
    ],
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
    die("abstract");
}

sub log_event
{
    return;
    my ($self,$str) = @_;
    my $dir = $self->dir;
    my @name = split("=",$self);
    my $fh = IO::File->new(">> /gscmnt/sata835/info/medseq/virome/workflow/logfile.txt");#monitor
    print $fh localtime(time) . "\t " . $name[0] . ":\t$str\n";
    $fh->close();
}
1;


