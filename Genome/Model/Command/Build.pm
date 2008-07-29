package Genome::Model::Command::Build;

use strict;
use warnings;

use Data::Dumper;

use above "Genome";
use Command; 


class Genome::Model::Command::Build {
    is => 'Genome::Model::Event',
    has => [],
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "do all the work after creation to produce a model of the genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel
EOS
}

sub help_detail {
    return <<"EOS"
This defines all of the steps necessary to produces a model, which are picked up by the job monitor and run.
(You can use the "run jobs" command to launch all of the jobs directly as well.)
EOS
}

sub subordinate_job_classes {
    return ();
}

1;

