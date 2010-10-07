package Genome::Model::Build::Command::Restart;

use strict;
use warnings;

use Genome;

require Carp;
require Cwd;
use Data::Dumper 'Dumper';

class Genome::Model::Build::Command::Restart {
    is => 'Genome::Command::Base',
    has => [
        builds => {
            is => 'Genome::Model::Build',
            shell_args_position => 1,
            is_many => 1,
            doc => 'Build(s) to use. Resolved from command line via text string.',
        },
        lsf_queue => {
            is => 'Text',
            default_value => 'workflow',
            is_optional => 1,
            doc => 'Queue to restart the master job in (events stay in their original queue)'
        },
        restart => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'Restart with a new workflow, overrides the default of resuming an old workflow'
        },
# NYI: after refactoring to Genome::Command::Base and Genome::Model::Build
#        software_revision => {
#            is => 'Text',
#            is_optional => 1,
#            doc => 'The software revision directory to be used by the build(s). Defaults to the current used libs via used_libs_perl5lib_prefix in UR::Util.',
#        }
    ],
};

sub sub_command_sort_position { 5 }

sub help_brief {
    "Restart a builds master job on a blade";
}

sub help_detail {
    return help_brief();
}

sub execute {
    my $self = shift;

    my %params;
    $params{fresh_workflow} = $self->restart if ($self->restart);
    $params{server_dispatch} = $self->lsf_queue if ($self->lsf_queue);

    my @builds = $self->builds;
    my $build_count = scalar(@builds);
    my $failed_count = 0;
    my @errors;
    for my $build (@builds) {
        my $rv = eval {$build->restart(%params)};
        if ($rv) {
            $self->status_message("Build (".$build->__display_name__.") launched to LSF.\nAn initialization email will be sent once the build begins running.");
        }
        else {
            $self->error_message($@);
            $failed_count++;
            push @errors, "Failed to restart build (" . $build->__display_name__ . ").";
        }
    }
    for my $error (@errors) {
        $self->status_message($error);
    }
    if ($build_count > 1) {
        $self->status_message("Stats:");
        $self->status_message(" Restarted: " . ($build_count - $failed_count));
        $self->status_message("    Errors: " . $failed_count);
        $self->status_message("     Total: " . $build_count);
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

1;

#$HeadURL$
#$Id$
