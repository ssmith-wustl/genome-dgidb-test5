package Genome::Model::Build::Command::Start;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Build::Command::Start {
    is => 'Genome::Command::Base',
    doc => "Create and start a build.",
    has_optional => [
        # not really optionally but needs to be for backwards compatibility
        model => {
            is => 'Genome::Model',
            doc => 'Model to build. Resolved from command line via text string.',
            shell_args_position => 1,
        },
        # keeping model_identifier for backwards compatibility
        model_identifier => {
            is => 'Text',
            doc => '(Deprecated, just use model.) Model identifier.  Use model id or name.',
            is_deprecated => 1,
        },
        job_dispatch => {
#            default_value => 'apipe',
#            is_constant => 1,
            doc => 'dispatch specification: an LSF queue or "inline"',
        },
        server_dispatch => {
#            default_value => 'workflow',
#            is_constant => 1,
            doc => 'dispatch specification: an LSF queue or "inline"',
        },
        data_directory => { },
        force => {
            is => 'Boolean',
            default_value => 0,
            doc => 'Force a new build even if existing builds are running.',
        },
        build => {
            is => 'Genome::Model::Build',
            doc => 'Da build.',
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

#< Execute >#
sub execute {
    my $self = shift;

    my $model;
    # For backward compatability
    if ($self->model_identifier && !$self->model) {
        my $model_from_text = $self->resolve_param_value_from_cmdline_text('model', 'Genome::Model', $self->model_identifier);
        $self->model($model_from_text);
    }

    # Get model
    if ($self->model) {
        $model = $self->model;
    }
    else {
        $self->error_message("You must specify a model");
    }
    return unless ($model);

    # Check running builds, only if we are not forcing
    unless ( $self->force ) {
        $self->_verify_no_other_builds_running
            or return;
    }

    my @p;
    if ($self->data_directory) {
        push @p, data_directory => $self->data_directory;
    }

    my $server_dispatch;
    my $job_dispatch;

    if (defined $self->server_dispatch) {
        $server_dispatch = $self->server_dispatch;
    } elsif ($model->processing_profile->can('server_dispatch') && defined $model->processing_profile->server_dispatch) {
        $server_dispatch = $model->processing_profile->server_dispatch;
    } else {
        $server_dispatch = 'workflow';
    }

    if (defined $self->job_dispatch) {
        $job_dispatch = $self->job_dispatch;
    } elsif ($model->processing_profile->can('job_dispatch') && defined $model->processing_profile->job_dispatch) {
        $job_dispatch = $model->processing_profile->job_dispatch;
    } else {
        $job_dispatch = 'apipe';
    }

    # Lock the model
    $self->_lock_model_and_create_commit_and_rollback_observers( $model->id )
        or return;
    
    # Create the build
    my $build = Genome::Model::Build->create(model_id => $model->id, @p);
    unless ( $build ) {
        $self->error_message(
            sprintf("Can't create build for model (%s %s)", $model->id, $model->name) 
        );
        return;
    }
    $self->build($build);

    # Launch the build
    my $started;
    eval {
        $started = $build->start(
            server_dispatch => $server_dispatch,
            job_dispatch => $job_dispatch
        );
    };

    my $error = $@;
    if($error or not $started) {
        my $message = $error || $build->error_message;
        $self->error_message("Failed to start new build: " . $message);
        $build->delete;
        return;
    }

    my $msg = sprintf(
        "Build (ID: %s DIR: %s) created, scheduled and launched to LSF.\nAn initialization email will be sent once the build begins running.\n",
        $build->id,
        $build->data_directory,
    );
    $self->status_message($msg);

    my $uri = sprintf('%s/genome/model/build/status.html?id=%s',
        Genome::Config->base_web_uri(), 
        $build->id,
    );
    my $browser = $ENV{BROWSER} || 'firefox';
    $self->status_message("Monitor from the web at $uri\n");
    #If we did want to do this, shouldn't launch until after we commit.  But even still it may not be a good idea.
    #system "$browser $uri";

    #If a build has been requested, this build fulfills that request.
    $model->build_requested(0);
    return 1;
}

sub _resolve_model {
    my $self = shift;

    # Make sure we got an identifier
    my $model_identifier = $self->model_identifier;
    unless ( $model_identifier ) {
        $self->error_message("No model identifier given to get model.");
        return;
    }

    my $model;
    # By id if it's an integer
    if ( $self->model_identifier =~ /^$RE{num}{int}$/ ) {
        $model = Genome::Model->get($model_identifier);
    }

    # Try by name if id wasn't an integer or didn't work
    unless ( $model ) {
        $model = Genome::Model->get(name => $model_identifier);
    }

    # Neither worked
    unless ( $model ) {
        $self->error_message("Can't get model for identifier ($model_identifier).  Tried getting as id and name.");
        return;
    }

    return $self->model($model);
}

sub _verify_no_other_builds_running {
    my $self = shift;

    my @running_builds = $self->model->running_builds;
    if ( @running_builds ) {
        $self->error_message(
            sprintf(
                "Model (%s %s) already has builds running: %s. Use the 'force' param to overirde this and start a new build.",
                $self->model->id,
                $self->model->name,
                join(', ', map { $_->id } @running_builds),
            )
        );
        return;
    } 

    return 1;
}

sub _lock_model_and_create_commit_and_rollback_observers {
    my ($self, $model_id) = @_;

    # lock
    my $lock_id = '/gsc/var/lock/build_start/'.$model_id;
    my $lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => $lock_id, 
        block_sleep => 3,
        max_try => 3,
    );
    unless ( $lock ) {
        $self->error_message(
            "Failed to get build start lock for model $model_id. This means someone|thing else is attempting to build this model. Please wait a moment, and try again. If you think that this model is incorrectly locked, please put a ticket into the apipe support queue."
        );
        return;
    }

    # create observers to unlock
    my $commit_observer;
    my $rollback_observer;

    $commit_observer = UR::Context->add_observer(
        aspect => 'commit',
        callback => sub {
            #print "Commit\n";
            # unlock - no error on failure
            Genome::Utility::FileSystem->unlock_resource(
                resource_lock => $lock_id,
            );
            # delete and undef observers
            $commit_observer->delete;
            undef $commit_observer;
            $rollback_observer->delete;
            undef $rollback_observer;
        }
    );

    $rollback_observer = UR::Context->add_observer(
        aspect => 'rollback',
        callback => sub {
            #print "Rollback\n";
            # unlock - no error on failure
            Genome::Utility::FileSystem->unlock_resource(
                resource_lock => $lock_id,
            );
            # delete and undef observers so they do not persist
            # they should have been deleted in the rollback, 
            #  but try to delete again just in case
            if ( $rollback_observer ) {
                $rollback_observer->delete unless $rollback_observer->isa('UR::DeletedRef');
                undef $rollback_observer;
            }
            if ( $commit_observer ) {
                $commit_observer->delete unless $commit_observer->isa('UR::DeletedRef');
                undef $commit_observer;
            }
        }
    );

    return 1;
}

1;

#$HeadURL$
#$Id$
