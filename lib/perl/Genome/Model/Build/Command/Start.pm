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
    my $model_count = scalar(@models);
    my $failed_count = 0;
    my @errors;
    for my $model (@models) {
        if (!$self->force && $model->running_builds) {
            $self->error_message("Model (".$model->name.") already has running builds. Use the '--force' param to override this and start a new build.");
            push @errors, $self->error_message;
            next;
        }
        my $build = Genome::Model::Build->create(model_id => $model->id, %create_params);
        unless ($build) {
            $self->error_message("Could not create build for model (".$model->name.".");
            push @errors, $self->error_message;
            next;
        }
        my @builds = $self->builds;
        push @builds, $build;
        $self->builds(\@builds);
        my $rv = eval {$build->start(%start_params)};
        if ($rv) {
            $self->status_message("Successfully started build (" . $build->__display_name__ . ").");
        }
        else {
            $failed_count++;
            $self->error_message("Failed to start build (" . $build->__display_name__ . "): $@.");
            push @errors, $self->error_message;
            next;
        }
    }
    for my $error (@errors) {
        $self->status_message($error);
    }
    if ($model_count > 1) {
        $self->status_message("Stats:");
        $self->status_message(" Started: " . ($model_count - $failed_count));
        $self->status_message("  Errors: " . $failed_count);
        $self->status_message("   Total: " . $model_count);
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
