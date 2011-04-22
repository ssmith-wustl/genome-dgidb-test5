package Genome::Model::Build::Command::Queue;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Build::Command::Queue {
    is => 'Genome::Command::Base',
    doc => "Queue the starting of a build.",
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            doc => 'Model(s) to build. Resolved from command line via text string.',
            shell_args_position => 1,
        },
    ],

};

sub sub_command_sort_position { 1 }

sub help_synopsis {
    return <<EOS;
genome model build queue 1234

genome model build queue somename



EOS
}

sub help_detail {
    return <<EOS;
Request that a new build for the model be scheduled by the build cron.
EOS
}

sub execute {
    my $self = shift;

    my @models = $self->models;
    map($_->build_requested(1), @models);

    return 1;
}

1;

