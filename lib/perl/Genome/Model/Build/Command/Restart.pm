package Genome::Model::Build::Command::Restart;

use strict;
use warnings;

use Genome;

require Carp;
require Cwd;
use Data::Dumper 'Dumper';

class Genome::Model::Build::Command::Restart {
    is => 'Genome::Model::Build::Command::Base',
    has => [
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
    my @errors;
    for my $build (@builds) {
        my $transaction = UR::Context::Transaction->begin();
        my $successful = eval {$build->restart(%params)};
        if ($successful) {
            if ($transaction->commit) {
                $self->status_message("Build (".$build->__display_name__.") launched to LSF.\nAn initialization email will be sent once the build begins running.");
            }
        }
        else {
            push @errors, "Failed to restart build (" . $build->__display_name__ . "): $@.";
            $transaction->rollback;
        }
    }

    $self->display_summary_report(scalar(@builds), @errors);

    return !scalar(@errors);
}

1;

#$HeadURL$
#$Id$
