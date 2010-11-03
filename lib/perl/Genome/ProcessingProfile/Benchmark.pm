package Genome::ProcessingProfile::Benchmark;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Benchmark {
    is => 'Genome::ProcessingProfile',
    has => [
        server_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            # If value is not specified, or not 'inline', will default to 'workflow' queue
            value => 'workflow',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        job_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            # This is a queue name, but 'inline' is reserved for run on local machine.
            value => 'benchmark',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        }
    ],
    has_param => [
        command => {
            doc => 'command to benchmark',
        },
        args => {
            is_optional => 1,
            doc => 'the arguments to prepend before the model input \'command_arguments\'',
        },
        lsf_queue => {
            is_optional => 1,
            value => 'long'
        },
        lsf_param => {
            is_optional => 1,
            value => ''
        },
        snapshot_type => {
            is_optional => 1,
            value => 'default'
        }
    ],
    doc => "benchmark profile captures statistics after command execution"
};

sub create {
    my $class = shift;
    my $params = $class->define_boolexpr(@_);

    if (my $st = $params->value_for('snapshot_type')) {
        unless ($class->_system_snapshot_package($st)) {
            $class->error_message("No system snapshot class defined for $st");
            return;
        }
    }

    return $class->SUPER::create(@_);
}

sub _initialize_model {
    my ($self,$model) = @_;
    $self->status_message("defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__);
    return 1;
}

sub _initialize_build {
    my ($self,$build) = @_;
    $self->status_message("defining new build " . $build->__display_name__ . " for profile " . $self->__display_name__);
    return 1;
}

sub _resolve_workflow_for_build {
    my $self = shift;
    my $workflow = $self->SUPER::_resolve_workflow_for_build(@_);

    my $operation_type = Workflow::OperationType::Command->get('Genome::Model::Event::Build::ProcessingProfileMethodWrapper');
    $operation_type->lsf_resource($self->lsf_param);
    $operation_type->lsf_queue($self->lsf_queue);

    return $workflow;
}


sub _system_snapshot_package {
    my $self = shift;
    my $type = shift;

    $type ||= $self->snapshot_type;
    return unless $type;

    my $package = 'Genome::Utility::SystemSnapshot::' . ucfirst(lc($type));

    eval "use $package;";
    return if ($@);
    return $package;
}

sub _system_snapshot {
    # FIXME: Make these stubs and subclass when we get closer to finished
    my $self = shift;
    my $dir = shift;

    # We create a cache file for this build
    my $cache = "$dir/system_snapshot.cache";
    return if (! defined $dir);

    my $package = $self->_system_snapshot_package;

    my $s = $package->new($cache);
    return $s->run();
}

sub _set_metrics {
    # Stub to be overridden in a Benchmark subclass
    my ($self,$build,$metrics) = @_;
    foreach my $key (keys %$metrics) {
        $build->set_metric($key,$metrics->{$key});
    }
}

sub _execute_build {
    my ($self,$build) = @_;
    $self->status_message("executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__);

    # combine params with build inputs and produce output in the build's data directory

    $DB::single=1;

    my $cmd = $self->command;

    my @inputs = $build->inputs(name => 'command_arguments');
    @inputs = map { $_->{value_id} } @inputs ;
    my $args = join(' ', @inputs);

    my $dir = $build->data_directory;

    $self->_system_snapshot($dir);

    my $exit_code = system "/usr/bin/time -v $cmd $args >$dir/output 2>$dir/errors";
    $exit_code = $exit_code >> 8;
    if ($exit_code != 0) {
        $self->status_message("Failed to run $cmd with args $args!  Exit code: $exit_code.");
        # FIXME: Not really sure what to do long term here.
        # We have a case of gmt soap de-novo-assemble not properly returning exit codes.
        # Don't return, fall through and finish getting metrics.
    }

    my $metrics = $self->_system_snapshot($dir);
    $self->_set_metrics($build,$metrics);

    return 1;
}

sub _validate_build {
    my $self = shift;
    my $dir = $self->data_directory;

    my @errors;
    unless (-e "$dir/output") {
        my $e = $self->error_message("No output file $dir/output found!");
        push @errors, $e;
    }
    unless (-e "$dir/errors") {
        my $e = $self->error_message("No output file $dir/errors found!");
        push @errors, $e;
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

1;
