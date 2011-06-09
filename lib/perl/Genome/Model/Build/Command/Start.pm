package Genome::Model::Build::Command::Start;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Build::Command::Start {
    is => 'Genome::Command::Base',
    doc => "Create and start a build.",
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            doc => 'Model(s) to build. Resolved from command line via text string.',
            shell_args_position => 1,
        },
    ],
    has_optional => [
        job_dispatch => {
            doc => 'dispatch specification: an LSF queue or "inline"',
        },
        server_dispatch => {
            doc => 'dispatch specification: an LSF queue or "inline"',
        },
        data_directory => { },
        force => {
            is => 'Boolean',
            default_value => 0,
            doc => 'Force a new build even if existing builds are running.',
        },
        builds => {
            is => 'Genome::Model::Build',
            is_many => 1,
            is_output => 1,
        },
        max_builds => {
            is => 'Integer',
        },
    ],

};

sub sub_command_sort_position { 1 }

sub help_synopsis {
    return <<EOS;
genome model build start 1234

genome model build start somename
# default values for dispatching will be either -s workflow -j apipe
# or come from the processing profile if available as a param

genome model build start somename -s workflow -j apipe
# run the server in the workflow queue, and jobs in the apipe queue

genome model build start somename -s inline -j inline
# run the server inline, and the jobs inline

EOS
}

sub help_detail {
    return <<EOS;
Make a new build for the specified model, and initiate execution of the build processes.

Builds with a defined workflow will run asynchronously.  Simple builds will run immediately
and this command will wait for them to finish.
EOS
}

sub execute {
    my $self = shift;

    my %create_params;
    $create_params{data_directory} = $self->data_directory if ($self->data_directory);
    my %start_params;
    $start_params{job_dispatch} = $self->job_dispatch if ($self->job_dispatch);
    $start_params{server_dispatch} = $self->server_dispatch if ($self->server_dispatch);

    my @models = $self->models;
    my @errors;
    my $builds_started = 0;
    my $total_count = 0;
    for my $model (@models) {
        if ($self->max_builds && $builds_started >= $self->max_builds){
            $self->status_message("Already started max builds $builds_started, quitting");
            last; 
        }
        $total_count++;
        $self->status_message("Trying to start " . $model->__display_name__ . "...");
        my $transaction = UR::Context::Transaction->begin();
        my $build = eval {
            if (!$self->force && ($model->running_builds or $model->scheduled_builds)) {
                die $self->error_message("Model (".$model->name.", ID: ".$model->id.") already has running or scheduled builds. Use the '--force' param to override this and start a new build.");
            }

            my $build = Genome::Model::Build->create(model_id => $model->id, %create_params);
            unless ($build) {
                die $self->error_message("Failed to create build for model (".$model->name.", ID: ".$model->id.").");
            }

            my $build_started = $build->start(%start_params);
            unless ($build_started) {
                die $self->error_message("Failed to start build (" . $build->__display_name__ . "): $@.");
            }
            return $build;
        };
        if ($build and $transaction->commit) {
            $self->status_message("Successfully started build (" . $build->__display_name__ . ").");
            $builds_started++;

            # Record newly created build so other tools can access them.
            # TODO: should possibly be part of the object class
            $self->add_build($build);
        }
        else {
            push @errors, $model->__display_name__ . ": " . $@;
            $transaction->rollback;
        }
    }

    $self->display_builds_started();
    $self->display_summary_report($total_count, @errors);

    return !scalar(@errors);
}

sub display_builds_started {
    my $self = shift;
    my @builds = $self->builds;
    if (@builds) {
        $self->status_message("Started builds: " . join(' ', map { $_->id } @builds));
    }
    return 1;
}
1;

