package Genome::Model::Build;

use strict;
use warnings;

use Genome;

use Carp;
use Data::Dumper 'Dumper';
use File::Path;
use File::Find 'find';
use File::Basename qw/ dirname fileparse /;
use Regexp::Common;
use Workflow;
use YAML;

class Genome::Model::Build {
    is => 'Genome::Notable',
    type_name => 'genome model build',
    table_name => 'GENOME_MODEL_BUILD',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    id_by => [
        build_id => { is => 'NUMBER', },
    ],
    has => [
        subclass_name           => { is => 'VARCHAR2', len => 255, is_mutable => 0, column_name => 'SUBCLASS_NAME',
                                     calculate_from => ['model_id'],
                                     # We subclass via our model's type_name (which is via it's processing profile's type_name)
                                     calculate => sub {
                                                      my($model_id) = @_;
                                                      return unless $model_id;
                                                      my $model = Genome::Model->get($model_id);
                                                      Carp::croak("Can't find Genome::Model with ID $model_id while resolving subclass for Build") unless $model;
                                                      return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($model->type_name);
                                                  }
                                   },
        data_directory          => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
        model                   => { is => 'Genome::Model', id_by => 'model_id' },
        model_id                => { is => 'NUMBER', implied_by => 'model', constraint_name => 'GMB_GMM_FK' },
        model_name              => { via => 'model', to => 'name' },
        type_name               => { via => 'model' },
        subject                 => { via => 'model' },
        subject_id              => { via => 'model' },
        subject_name            => { via => 'model' },
        processing_profile      => { via => 'model' },
        processing_profile_id   => { via => 'model' },
        processing_profile_name => { via => 'model' },
        the_events              => { is => 'Genome::Model::Event', reverse_as => 'build', is_many => 1 },
        the_events_statuses     => { via => 'the_events', to => 'event_status' },
        the_master_event        => { is => 'Genome::Model::Event', reverse_as => 'build', where => [ event_type => 'genome model build' ], is_many => 1, is_constant => 1},
        run_by                  => { via => 'the_master_event', to => 'user_name' },
        status                  => { via => 'the_master_event', to => 'event_status', is_mutable => 1 },
        date_scheduled          => { via => 'the_master_event', to => 'date_scheduled', },
        date_completed          => { via => 'the_master_event', to => 'date_completed' },
        master_event_status     => { via => 'the_master_event', to => 'event_status' },
    ],
    has_optional => [
        disk_allocation   => { is => 'Genome::Disk::Allocation', calculate_from => [ 'class', 'id' ],
                               calculate => q(
                                    my $disk_allocation = Genome::Disk::Allocation->get(
                                                          owner_class_name => $class,
                                                          owner_id => $id,
                                                      );
                                    return $disk_allocation;
                                ) },
        software_revision => { is => 'VARCHAR2', len => 1000 },
    ],
    has_many_optional => [
        inputs => { 
            is => 'Genome::Model::Build::Input', 
            reverse_as => 'build', 
            doc => 'Inputs assigned to the model when the build was created.' 
        },
        instrument_data_inputs => {
            is => 'Genome::Model::Build::Input',
            reverse_as => 'build',
            where => [ name => 'instrument_data' ],
        },
        instrument_data  => { 
            is => 'Genome::InstrumentData', 
            via => 'inputs', 
            to => 'value', 
            is_mutable => 1, 
            where => [ name => 'instrument_data' ], 
            doc => 'Instrument data assigned to the model when the build was created.' 
        },
        instrument_data_ids => { via => 'instrument_data', to => 'id', is_many => 1, },
        from_build_links => { is => 'Genome::Model::Build::Link', reverse_as => 'to_build', 
                              doc => 'bridge table entries where this is the \"to\" build(used to retrieve builds this build is \"from\")' },
        from_builds      => { is => 'Genome::Model::Build', via => 'from_build_links', to => 'from_build', 
                              doc => 'Genome builds that contribute \"to\" this build' },
        to_build_links   => { is => 'Genome::Model::Build::Link', reverse_as => 'from_build', 
                              doc => 'bridge entries where this is the \"from\" build(used to retrieve builds builds this build is \"to\")' },
        to_builds        => { is => 'Genome::Model::Build', via => 'to_build_links', to => 'to_build', 
                              doc => 'Genome builds this build contributes \"to\"' },
        attributes       => { is => 'Genome::MiscAttribute', reverse_as => '_build', where => [ entity_class_name => 'Genome::Model::Build' ] },
        metrics          => { is => 'Genome::Model::Metric', reverse_as => 'build', 
                              doc => 'Build metrics' },
        variants         => { is => 'Genome::Model::BuildVariant', reverse_as => 'build', 
                              doc => 'variants linked to this build... currently only for Somatic builds but need this accessor for get_all_objects' },
        group_ids        => { via => 'model', to => 'group_ids', is_many => 1, },
        group_names      => { via => 'model', to => 'group_names', is_many => 1, },

        projects         => { is => 'Genome::Site::WUGC::Project', via => 'model' },
        work_orders      => { is => 'Genome::WorkOrder', via => 'projects' },
        work_order_names => { via => 'work_orders', to => 'name' },
        work_order_numbers => { via => 'work_orders', to => 'id' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = shift;
    return $self->id . ' of ' . $self->model->name;
}

# TODO Remove this
sub _resolve_subclass_name_by_sequencing_platform { # only temporary, subclass will soon be stored
    my $class = shift;

    Carp::confess("this is used by sub-classes which further subclassify by sequencing platform!")
        if $class eq __PACKAGE__;

    my $sequencing_platform;
    if (ref($_[0]) and $_[0]->isa('Genome::Model::Build')) {
        $sequencing_platform = $_[0]->model->sequencing_platform;
    } 
    else {
        my %params;
        if (ref($_[0]) and $_[0]->isa("UR::BoolExpr")) {
            %params = $_[0]->params_list;
        }
        else {
            %params = @_;
        }
        my $model_id = $params{model_id};
        $class->_validate_model_id($params{model_id})
            or return;
        my $model = Genome::Model->get($params{model_id});
        unless ( $model ) {
            Carp::confess("Can't get model for id: .".$params{model_id});
        }
        $sequencing_platform = $model->sequencing_platform;
    }

    return unless $sequencing_platform;

    return $class. '::'.Genome::Utility::Text::string_to_camel_case($sequencing_platform);
}

# auto generate sub-classes for any valid processing profile
sub __extend_namespace__ {
    my ($self,$ext) = @_;

    my $meta = $self->SUPER::__extend_namespace__($ext);
    return $meta if $meta;
    
    my $pp_subclass_name = 'Genome::ProcessingProfile::' . $ext;
    my $pp_subclass_meta = UR::Object::Type->get($pp_subclass_name);
    if ($pp_subclass_meta and $pp_subclass_name->isa('Genome::ProcessingProfile')) {
        my $build_subclass_name = 'Genome::Model::Build::' . $ext;
        my $build_subclass_meta = UR::Object::Type->define(
            class_name => $build_subclass_name,
            is => 'Genome::Model::Build',
        );
        die "Error defining $build_subclass_name for $pp_subclass_name!" unless $build_subclass_meta;
        return $build_subclass_meta;
    }
    return;
}

sub create {
    my $class = shift;
    if ($class eq __PACKAGE__ or $class->__meta__->is_abstract) {
        # Let the base class re-call the constructor from the correct sub-class
        return $class->SUPER::create(@_);
    }

    my $self = $class->SUPER::create(@_);
    return unless $self;
    
    eval {
        # Give the model a chance to update itself prior to copying inputs from it
        unless ($self->model->check_for_updates) {
            Carp::confess "Could not update model!";
        }

        # Now copy (updated) inputs to build
        unless ($self->_copy_model_inputs) {
            Carp::confess "Could not copy model inputs from model " . $self->model->__display_name__ . " to new build!";
        }

        # Allow processing profile to initialize build
        unless ($self->processing_profile->_initialize_build($self)) {
            Carp::confess "Processing profile " . $self->processing_profile->__display_name__ .
                " could not initialize new build of model " . $self->model->__display_name__;
        }

        # Create master event, which stores status/user/date created, etc
        unless ($self->_create_master_event) {
            Carp::confess "Could not create master event for new build of model " . $self->model->__display_name__;
        }

        $self->add_note(
            header_text => 'Build Created',
        );
    };

    if ($@) {
        $self->error_message("Could not create new build of model " . $self->__display_name__ . ", reason: $@");
        $self->delete;
        return;
    }

    return $self;
}

sub _create_master_event {
    my $self = shift;
    my $event = Genome::Model::Event->create(
        event_type => 'genome model build',
        event_status => 'New',
        model_id => $self->model->id,
        build_id => $self->id,
    );
    return $event;
}

sub _copy_model_inputs {
    my $self = shift;

    # Failing to copy an input SHOULD NOT be fatal. If the input is required for the build 
    # to run, it'll be caught when the build is verified as part of the start method, which
    # will leave the build in an "unstartable" state that can be reviewed later.
    for my $input ($self->model->inputs) {
        eval {
            my %params = map { $_ => $input->$_ } (qw/ name value_class_name value_id filter_desc /);

            # Resolve inputs pointing to a model to a build. 
            if($params{value_class_name}->isa('Genome::Model')) {
                my $input_name = $input->name;
                my $existing_input = $self->inputs(name => $input_name);
                if ($existing_input) {
                    my $existing_input_value = $existing_input->value;
                    if ($existing_input_value && $existing_input_value->isa('Genome::Model::Build')) {
                        die "Input with name $input_name already exists for build!";
                    }
                }

                my $input_model = $input->value;
                my $input_build = $self->select_build_from_input_model($input_model);
                unless($input_build) {
                    die "Could not resolve a build of model " . $input_model->__display_name__; 
                }

                $params{value_class_name} = $input_build->class;
                $params{value_id} = $input_build->id;
            }

            unless ($self->add_input(%params)) {
                die "Could not copy model input " . $params{name} . " with ID " . $params{value_id} .
                    " and class " . $params{value_class_name} . " to new build"; 
            }
        };
        if ($@) {
            $self->warning_message("Could not copy model input " . $input->__display_name__ .
                " to build " . $self->__display_name__ . " of model " . $self->model->__display_name__);
            next;
        }
    }

    return 1;

}

sub select_build_from_input_model {
    my ($self, $model) = @_;
    return $model->last_complete_build;
}

sub instrument_data_count {
    my $self = shift;
    my @instrument_data = $self->instrument_data;
    if (@instrument_data) {
        return scalar(@instrument_data);
    }
    return 0;
}

# why is this not a defined relationship above? -ss
sub events {
    my $self = shift;
    my @events = Genome::Model::Event->get(
        model_id => $self->model_id,
        build_id => $self->build_id,
        @_,
    );
    return @events;
}

# why is this not a defined relationship above? -ss
sub build_events {
    my $self = shift;
    my @build_events = Genome::Model::Event::Build->get(
        model_id => $self->model_id,
        build_id => $self->build_id,
        @_
    );
    return @build_events;
}

sub build_event {
    my $self = shift;
    my @build_events = $self->build_events;
    if (scalar(@build_events) > 1) {
        my $error_message = 'Found '. scalar(@build_events) .' build events for model id '.
        $self->model_id .' and build id '. $self->build_id ."\n";
        for (@build_events) {
            $error_message .= "\t". $_->desc .' '. $_->event_status ."\n";
        }
        die($error_message);
    }
    return $build_events[0];
}

sub workflow_name {
    my $self = shift;
    return $self->build_id . ' all stages';
}

sub workflow_instances {
    my $self = shift;
    my @instances = Workflow::Operation::Instance->get(
        name => $self->workflow_name,
    );
    return @instances;
}

sub newest_workflow_instance {
    my $self = shift;
    my @sorted = sort { 
        $b->id <=> $a->id
    } $self->workflow_instances;
    if (@sorted) { 
        return $sorted[0];
    } else {
        return;
    }
}

sub cpu_slot_hours {
    my $self = shift;
    # TODO: get with Matt and replace with workflow interrogation
    my @events = $self->events(@_);
    my $s = 0;
    for my $event (@events) {
        # the master event has an elapsed time for the whole process: don't double count
        next if (ref($event) eq 'Genome::Model::Event::Build');

        # this would be a method on event, but we won't keep it that long
        # it's just good enough to do the calc for the grant 2011-01-30 -ss
        my $cores;
        if (ref($event) =~ /deduplicate/i) {
            $cores = 4;
        }
        elsif (ref($event) =~ /AlignReads/) {
            $cores = 4;
        }
        else {
            $cores = 1;
        }
        my $e = UR::Time->datetime_to_time($event->date_completed)
                - 
                UR::Time->datetime_to_time($event->date_scheduled);
        if ($e < 0) {
            warn "event " . $event->__display_name__ . " has negative elapsed time!";
            next;
        }
        $s += ($e * $cores);
    }
    return $s/(60*60);
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    # Default of 500 MiB in case a subclass fails to
    # override this method.  At least this way there
    # will be an allocation, which will likely be
    # wildly inaccurate, but if the build fails to fail,
    # when it finishes, it will reallocate down to the
    # actual size.  Whereas the previous behaviour 
    # (return undef) caused *no* allocation to be made.
    # Which it has been decided is a bigger problem.
    return 512_000;
}

# If the data directory is not set, resolving it requires making an allocation.  A build is unlikely to
# make a new allocation at any other time, so a separate build instance method for allocating is not
# provided.
sub get_or_create_data_directory {
    my $self = shift;
    return $self->data_directory if $self->data_directory;

    my $allocation_path = 'model_data/' . $self->model->id . '/build'. $self->build_id;
    my $kb_requested = $self->calculate_estimated_kb_usage;
    unless ($kb_requested) {
        $self->error_message("Could not estimate kb usage for allocation!");
        return;
    }

    my $disk_group_name = $self->processing_profile->_resolve_disk_group_name_for_build($self);
    unless ($disk_group_name) {
        $self->error_message('Failed to resolve a disk group for a new build!');
        return;
    }

    my $disk_allocation = Genome::Disk::Allocation->create(
        disk_group_name => $disk_group_name,
        allocation_path => $allocation_path,
        kilobytes_requested => $kb_requested,
        owner_class_name => $self->class,
        owner_id => $self->id,
    );
    unless ($disk_allocation) {
        $self->error_message("Could not create allocation for build " . $self->__display_name__);
        return;
    }

    $self->data_directory($disk_allocation->absolute_path);
    return $self->data_directory;
}

sub reallocate {
    my $self = shift;
    my $disk_allocation = $self->disk_allocation or return 1; # ok - may not have an allocation

    unless ($disk_allocation->reallocate) {
        $self->warning_message('Failed to reallocate disk space.');
    }

    return 1;
}

sub log_directory { 
    return  $_[0]->data_directory . '/logs/';
}

sub reports_directory { 
    my $self = shift;
    return unless $self->data_directory;
    return $self->data_directory . '/reports/';
}

sub resolve_reports_directory { return reports_directory(@_); } #????

sub add_report {
    my ($self, $report) = @_;

    my $directory = $self->resolve_reports_directory;
    die "Could not resolve reports directory" unless $directory;
    if (-d $directory) {
        my $subdir = $directory . '/' . $report->name_to_subdirectory($report->name);
        if (-e $subdir) {
            $self->status_message("Sub-directory $subdir exists!   Moving it out of the way...");
            my $n = 1;
            my $max = 20;
            while ($n < $max and -e $subdir . '.' . $n) {
                $n++;
            }
            if ($n == $max) {
                die "Too many re-runs of this report!  Contact Informatics..."
            }
            rename $subdir, "$subdir.$n";
            if (-e $subdir) {
                die "failed to move old report dir $subdir to $subdir.$n!: $!";
            }
        }
    }
    else {
        $self->status_message("creating directory $directory...");
        unless (Genome::Sys->create_directory($directory)) {
            die "failed to make directory $directory!: $!";
        }
    }
    
    if ($report->save($directory)) {
        $self->status_message("Saved report to override directory: $directory");
        return 1;
    }
    else {
        $self->error_message("Error saving report!: " . $report->error_message());
        return;
    }
}

sub start {
    my $self = shift;
    my %params = @_;

    # Regardless of how this goes, build requested should be unset. And we also want to know what software was used.
    $self->model->build_requested(0);
    $self->software_revision($self->snapshot_revision) unless $self->software_revision;

    eval {
        # Validate build for start and collect tags that represent problems.
        # Croak is used here instead of confess to limit error message length. The entire message must fit into the
        # body text of a note, and can cause commit problems if the length exceeds what the db column can accept.
        # TODO Delegate to some other method to create the error message
        my @tags = $self->validate_for_start;
        if (@tags) {
            my @msgs;
            for my $tag (@tags) {
                push @msgs, $tag->__display_name__; 
            }
            Carp::croak "Build " . $self->__display_name__ . " could not be validated for start!\n" . join("\n", @msgs);
        }

        # Either returns the already-set data directory or creates an allocation for the data directory
        unless ($self->get_or_create_data_directory) {
            Carp::croak "Build " . $self->__display_name__ . " failed to resolve a data directory!";
        }

        # Give builds an opportunity to do some initialization after the data directory has been resolved
        unless ($self->post_allocation_initialization) {
            Carp::croak "Build " . $self->__display_name__ . " failed to initialize after resolving data directory!";
        }
        
        $self->the_master_event->schedule;

        # Creates a workflow for the build
        # TODO Initialize workflow shouldn't take arguments
        unless ($self->_initialize_workflow($params{job_dispatch} || 'apipe')) {
            Carp::croak "Build " . $self->__display_name__ . " could not initialize workflow!";
        }

        # Launches the workflow (in a pend state, it's resumed by a commit hook)
        unless ($self->_launch(%params)) {
            Carp::croak "Build " . $self->__display_name__ . " could not be launched!";
        }

        $self->add_note(
            header_text => 'Build Started',
        );
    };

    if ($@) {
        my $error = $@;
        $self->add_note(
            header_text => 'Unstartable',
            body_text => "Could not start build, reason: $error",
        );
        $self->the_master_event->event_status('Unstartable');
        $self->error_message("Could not start build " . $self->__display_name__ . ", reason: $error");
        return;
    }

    return 1;
}

sub post_allocation_initialization {
    return 1;
}

sub validate_for_start_methods {
    # Each method should return tags
    my @methods = (
        'inputs_have_compatible_reference',
    );
    return @methods;
}

sub validate_for_start {
    my $self = shift;

    my @tags;
    my @methods = $self->validate_for_start_methods;

    for my $method (@methods) {
        unless ($self->can($method)) {
            $self->warning_message("Validation method $method not found!");
            next;
        }
        my @returned_tags = grep { defined $_ } $self->$method(); # Prevents undef from being pushed to tags list
        push @tags, @returned_tags if @returned_tags; 
    }

    return @tags;
}

sub inputs_have_compatible_reference {
    my $self = shift;

    # We really should standardize what we call reference sequence...
    my @reference_sequence_methods = ('reference_sequence', 'reference', 'reference_sequence_build');

    my ($build_reference_method) = grep { $self->can($_) } @reference_sequence_methods;
    return unless $build_reference_method;
    my $build_reference_sequence = $self->$build_reference_method;

    my @inputs = $self->inputs;
    my @incompatible_properties;
    for my $input (@inputs) {
        my $object = $input->value;
        my ($input_reference_method) = grep { $object->can($_) } @reference_sequence_methods;
        next unless $input_reference_method;
        my $object_reference_sequence = $object->$input_reference_method;
        next unless $object_reference_sequence;

        unless($object_reference_sequence->is_compatible_with($build_reference_sequence)) {
            push @incompatible_properties, $input->name;
        }
    }

    my $tag;
    if (@incompatible_properties) {
        $tag = UR::Object::Tag->create(
            type => 'error',
            properties => \@incompatible_properties,
            desc => "Not compatible with build's reference sequence '" . $build_reference_sequence->__display_name__ . "'.",
        );
    }

    return $tag;
}


sub stop {
    my $self = shift;

    $self->status_message('Attempting to stop build: '.$self->id);

    my $user = getpwuid($<);
    if ($user ne 'apipe-builder' && $user ne $self->run_by) {
        $self->error_message("Can't stop a build originally started by: " . $self->run_by);
        return 0;
    }

    my $job = $self->_get_running_master_lsf_job; 
    if ( defined $job ) {
        $self->status_message('Killing job: '.$job->{Job});
        $self->_kill_job($job);
        $self = Genome::Model::Build->load($self->id);
    }

    $self->add_note(
        header_text => 'Build Stopped',
    );

    my $self_event = $self->build_event;
    my $error = Genome::Model::Build::Error->create(
        build_event_id => $self_event->id,
        stage_event_id => $self_event->id,
        stage => 'all stages',
        step_event_id => $self_event->id,
        step => 'main',
        error => 'Killed by user',
    );

    $self->status_message('Failing build: '.$self->id);
    unless ($self->fail($error)) {
        $self->error_message('Failed to fail build');
        return;
    }

    return 1
}

sub _kill_job {
    my ($self, $job) = @_;

    Genome::Sys->shellcmd(
        cmd => 'bkill '.$job->{Job},
    );

    my $i = 0;
    do {
        $self->status_message("Waiting for job to stop") if ($i % 10 == 0);
        $i++;
        sleep 1;
        $job = $self->_get_job( $job->{Job} );

        if ($i > 60) {
            $self->error_message("Build master job did not die after 60 seconds.");
            return 0;
        }
    } while ($job && ($job->{Status} ne 'EXIT' && $job->{Status} ne 'DONE'));

    return 1;
}

sub _get_running_master_lsf_job {
    my $self = shift;

    my $job_id = $self->the_master_event->lsf_job_id;
    return if not defined $job_id;

    my $job = $self->_get_job($job_id);
    return if not defined $job;

    if ( $job->{Status} eq 'EXIT' or $job->{Status} eq 'DONE' ) {
        return;
    }

    return $job;
}

sub _get_job {
    use Genome::Model::Command::Services::Build::Scan;
    my $self = shift;
    my $job_id = shift;

    my @jobs = ();
    my $iter = Job::Iterator->new($job_id);
    while (my $job = $iter->next) {
        push @jobs, $job;
    }

    if (@jobs > 1) {
        $self->error_message("More than 1 job found for this build? Alert apipe");
        return 0;
    }

    return shift @jobs;
}

# TODO Can this be removed now that the restart command is gone?
sub restart {
    my $self = shift;
    my %params = @_;

    $self->status_message('Attempting to restart build: '.$self->id);
   
    if (delete $params{job_dispatch}) {
        cluck $self->error_message('job_dispatch cannot be changed on restart');
    }
    
    my $user = getpwuid($<);
    if ($self->run_by ne $user) {
        croak $self->error_message("Can't restart a build originally started by: " . $self->run_by);
    }

    my $xmlfile = $self->data_directory . '/build.xml';
    if (!-e $xmlfile) {
        croak $self->error_message("Can't find xml file for build (" . $self->id . "): " . $xmlfile);
    }

    # Check if the build is running
    my $job = $self->_get_running_master_lsf_job;
    if ($job) {
        $self->error_message("Build is currently running. Stop it first, then restart.");
        return 0;
    }

    # Since the job is not running, check if there is server location file and rm it
    my $loc_file = $self->data_directory . '/server_location.txt';
    if ( -e $loc_file ) {
        $self->status_message("Removing server location file for dead lsf job: $loc_file");
        unlink $loc_file;
    }

    my $w = $self->newest_workflow_instance;
    if ($w && !$params{fresh_workflow}) {
        if ($w->is_done) {
            croak $self->error_message("Workflow Instance is complete");
        }
    }

    my $build_event = $self->build_event;
    for my $unrestartable_status ('Abandoned', 'Unstartable') {
        if($build_event->event_status eq $unrestartable_status) {
            $self->error_message("Can't restart a build that was " . lc($unrestartable_status) . ".  Start a new build instead.");
            return 0;
        }
    }

    $build_event->event_status('Scheduled');
    $build_event->date_completed(undef);

    for my $e ($self->the_events(event_status => ['Running','Failed'])) {
        $e->event_status('Scheduled');
    }
    
    return $self->_launch(%params);
}

sub _launch {
    my $self = shift;
    my %params = @_;

    local $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;

    # right now it is "inline" or the name of an LSF queue.
    # ultimately, it will be the specification for parallelization
    # including whether the server is inline, forked, or bsubbed, and the
    # jobs are inline, forked or bsubbed from the server
    my $server_dispatch;
    my $job_dispatch;
    my $model = $self->model;
    if (exists($params{server_dispatch})) {
        $server_dispatch = delete $params{server_dispatch};
    } elsif ($model->processing_profile->can('server_dispatch') && defined $model->processing_profile->server_dispatch) {
        $server_dispatch = $model->processing_profile->server_dispatch;
    } else {
        $server_dispatch = 'workflow';
    }

    if (exists($params{job_dispatch})) {
        $job_dispatch = delete $params{job_dispatch};
    } elsif ($model->processing_profile->can('job_dispatch') && defined $model->processing_profile->job_dispatch) {
        $job_dispatch = $model->processing_profile->job_dispatch;
    } else {
        $job_dispatch = 'apipe';
    }
    my $fresh_workflow = delete $params{fresh_workflow};

    my $job_group_spec;
    if (exists $params{job_group}) {
        my $job_group = delete $params{job_group};
        if ($job_group) {
            $job_group_spec = " -g $job_group";
        }
        else {
            $job_group_spec = "";
        }
    }
    else {
        my $user = getpwuid($<);
        $job_group_spec = ' -g /build2/' . $user;
    }

    die "Bad params!  Expected server_dispatch and job_dispatch!" . Data::Dumper::Dumper(\%params) if %params;

    my $build_event = $self->the_master_event;

    # TODO: send the workflow to the dispatcher instead of having LSF logic here.
    if ($server_dispatch eq 'inline') {
        # TODO: redirect STDOUT/STDERR to these files
        #$build_event->output_log_file,
        #$build_event->error_log_file,
        
        my %args = (
            model_id => $self->model_id,
            build_id => $self->id,
        );
        if ($job_dispatch eq 'inline') {
            $args{inline} = 1;
        }
        
        my $rv = Genome::Model::Command::Services::Build::Run->execute(%args);
        return $rv;
    }
    else {
        my $add_args = ($job_dispatch eq 'inline') ? ' --inline' : '';
        if ($fresh_workflow) {
            $add_args .= ' --restart';
        }

        my $lock = $self->_lock_model_for_start;
        return unless $lock;

        # bsub into the queue specified by the dispatch spec
        my $lsf_project = "build" . $self->id;
        my $user = Genome::Sys->username;
        my $lsf_command  = join(' ',
            'bsub -N -H',
            '-P', $lsf_project,
            '-q', $server_dispatch,
            $job_group_spec,
            '-u', $user . '@genome.wustl.edu',
            '-o', $build_event->output_log_file,
            '-e', $build_event->error_log_file,
            'annotate-log genome model services build run',
            $add_args,
            '--model-id', $model->id,
            '--build-id', $self->id,
        );
        my $job_id = $self->_execute_bsub_command($lsf_command);
        return unless $job_id;

        $build_event->lsf_job_id($job_id);

        return 1;
    }
}


sub _lock_model_for_start {
    my $self = shift;

    my $model_id = $self->model->id;
    my $lock_path = '/gsc/var/lock/build_start/' . $model_id;

    my $lock = Genome::Sys->lock_resource(
        resource_lock => $lock_path, 
        block_sleep => 3,
        max_try => 3,
    );
    unless ($lock) {
        print STDERR "Failed to get build start lock for model $model_id. This means someone|thing else is attempting to build this model. Please wait a moment, and try again. If you think that this model is incorrectly locked, please put a ticket into the apipe support queue.";
        return;
    }

    # create a change record so that if it is "undone" it will kill the job
    # create a commit observer to resume the job when build is committed to database
    my $process = UR::Context->process;
    my $unlock_sub = sub { Genome::Sys->unlock_resource(resource_lock => $lock) };
    my $lock_change = UR::Context::Transaction->log_change($self, 'UR::Value', $lock, 'external_change', $unlock_sub);
    my $commit_observer = $process->add_observer(aspect => 'commit', callback => $unlock_sub);
    unless ($commit_observer) {
        $self->error_message("Failed to add commit observer to unlock $lock.");
    }

    $self->status_message("Locked model ($model_id) while launching " . $self->__display_name__ . ".");
    return $lock;
}


sub _initialize_workflow {
    my $self = shift;
    my $lsf_queue_eliminate_me = shift || 'apipe';

    Genome::Sys->create_directory( $self->data_directory )
        or return;

    Genome::Sys->create_directory( $self->log_directory )
        or return;

    my $model = $self->model;
    my $processing_profile = $self->processing_profile;

    my $workflow = $processing_profile->_resolve_workflow_for_build($self,$lsf_queue_eliminate_me);

    ## so developers dont fail before the workflow changes get deployed to /gsc/scripts
    if ($workflow->can('notify_url')) {
        require UR::Object::View::Default::Xsl;

        my $cachetrigger = Genome::Config->base_web_uri;
        $cachetrigger =~ s/view$/cachetrigger/;

        my $url = $cachetrigger . '/' . UR::Object::View::Default::Xsl::type_to_url(ref($self)) . '/status.html?id=' . $self->id;
        $url .= ' ' . $cachetrigger . '/workflow/operation/instance/statuspopup.html?id=[WORKFLOW_ID]';

        $workflow->notify_url($url);
    }
    $workflow->save_to_xml(OutputFile => $self->data_directory . '/build.xml');
    
    return $workflow;
}

sub _execute_bsub_command { # here to overload in testing
    my ($self, $cmd) = @_;

    local $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;

    if ($ENV{UR_DBI_NO_COMMIT}) {
        $self->warning_message("Skipping bsub when NO_COMMIT is turned on (job will fail)\n$cmd");
        return 1;
    }

    my $bsub_output = `$cmd`;

    my $rv = $? >> 8;
    if ( $rv ) {
        $self->error_message("Failed to launch bsub (exit code: $rv) command:\n$bsub_output");
        return;
    }

    if ( $bsub_output =~ m/Job <(\d+)>/ ) {
        my $job_id = $1;

        # create a change record so that if it is "undone" it will kill the job
        my $bsub_undo = sub {
            $self->status_message("Killing LSF job ($job_id) for build " . $self->__display_name__ . ".");
            system("bkill $job_id");
        };
        my $lsf_change = UR::Context::Transaction->log_change($self, 'UR::Value', $job_id, 'external_change', $bsub_undo);
        if ($lsf_change) {
            $self->status_message("Recorded LSF job submission ($job_id).");
        }
        else {
            die $self->error_message("Failed to record LSF job submission ($job_id).");
        }

        # create a commit observer to resume the job when build is committed to database
        my $process = UR::Context->process;
        my $commit_observer = $process->add_observer(
            aspect => 'commit',
            callback => sub {
                my $bresume_output = `bresume $job_id`; chomp $bresume_output;
                $self->status_message($bresume_output) unless ( $bresume_output =~ /^Job <$job_id> is being resumed$/ );
            },
        );
        if ($commit_observer) {
            $self->status_message("Added commit observer to resume LSF job ($job_id).");
        }
        else {
            $self->error_message("Failed to add commit observer to resume LSF job ($job_id).");
        }

        return "$job_id";
    } 
    else {
        $self->error_message("Launched busb command, but unable to parse bsub output: $bsub_output");
        return;
    }
}

sub initialize {
    my $self = shift;

    $self->_verify_build_is_not_abandoned_and_set_status_to('Running')
        or return;
   
    $self->generate_send_and_save_report('Genome::Model::Report::BuildInitialized')
        or return;

    return 1;
}

sub fail {
    my ($self, @errors) = @_;

    # reload all the events
    my @e = Genome::Model::Event->load(build_id => $self->build_id);

    $self->_verify_build_is_not_abandoned_and_set_status_to('Failed', 1)
        or return;

    # set event status
    for my $e ($self->the_events(event_status => 'Running')) {
        $e->event_status('Failed');
    }

    $self->generate_send_and_save_report(
        'Genome::Model::Report::BuildFailed', {
            errors => \@errors,
        },
    )
        or return;
    
    # FIXME Don't know if this should go here, but then we would have to call success and abandon through the model
    my $last_complete_build = $self->model->resolve_last_complete_build;
    if ( $last_complete_build and $last_complete_build->id eq $self->id ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), which should not return this build (".$self->id."), but did.");
        # FIXME soon - return here
        # return;
    }

    for my $error (@errors) {
        $self->add_note(
            header_text => 'Failed Stage',
            body_text => $error->stage,
        );
        $self->add_note(
            header_text => 'Failed Step',
            body_text => $error->step,
        );
        $self->add_note(
            header_text => 'Failed Error',
            body_text => $error->error,
        );
    }
    
    return 1;
}

sub success {
    my $self = shift;

    # reload all the events
    my @e = Genome::Model::Event->load(build_id => $self->build_id);

    # set status
    $self->_verify_build_is_not_abandoned_and_set_status_to('Succeeded', 1)
        or return;

    # set event status
    for my $e ($self->the_events(event_status => ['Running','Scheduled'])) {
        $e->event_status('Abandoned');
    }

    # report - if this fails set status back to Running, then the workflow will fail it
    unless ( $self->generate_send_and_save_report( $self->report_generator_class_for_success ) ) {
        $self->_verify_build_is_not_abandoned_and_set_status_to('Running');
        return;
    }
    
    # Launch new builds for any convergence models containing this model.
    # To prevent infinite loops, don't do this for convergence builds.
    # FIXME convert this to use the commit callback and model links with a custom notify that doesn't require succeeded builds
    if($self->type_name !~ /convergence/) {
        for my $model_group ($self->model->model_groups) {
            eval {
                $model_group->schedule_convergence_rebuild;
            };
            if($@) {
                $self->error_message('Could not schedule convergence build for model group ' . $model_group->id . '.  Continuing anyway.');
            }
        }
    }

    my $commit_callback;
    $commit_callback = sub {
        $self->the_master_event->cancel_change_subscription('commit', $commit_callback); #only fire once
        $self->status_message('Firing build success commit callback.');
        my $result = eval {
            $self->processing_profile->_build_success_callback($self);
        };
        if($@) {
            $self->error_message('Error executing success callback: ' . $@);
            return;
        }
        unless($result) {
            $self->error_message('Success callback failed.');
            return;
        }

        return UR::Context->commit; #a separate commit is necessary for any changes in the callback
    };

    #The build itself has no __changes__ and UR::Context->commit() will not trigger the subscription if on that object, so
    #use the master build event which has just been updated to 'Succeeded' with the current time.
    $self->the_master_event->create_subscription(
        method => 'commit',
        callback => $commit_callback,
    );

    # reallocate - always returns true (legacy behavior)
    $self->reallocate; 

    # TODO Reconsider this method name
    $self->perform_post_success_actions;

    if ($self->model->class =~ /GenotypeMicroarray/) {
        $self->model->request_builds_for_dependent_cron_ref_align;
    }

    # FIXME Don't know if this should go here, but then we would have to call success and abandon through the model
    my $last_complete_build = $self->model->resolve_last_complete_build;
    unless ( $last_complete_build ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), but no build was returned.");
        # FIXME soon - return here
        #return;
    }
    unless ( $last_complete_build->id eq $self->id ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), which should return this build (".$self->id."), but returned another build (".$last_complete_build->id.").");
        # FIXME soon - return here
        #return;
    }

    return 1;
}

# TODO Reconsider this name
sub perform_post_success_actions {
    my $self = shift;
    return 1;
}

sub _verify_build_is_not_abandoned_and_set_status_to {
    my ($self, $status, $set_date_completed) = @_;

    my $build_event = $self->build_event;
    # Do we have a master event?
    unless ( $build_event ) {
        $self->error_message(
            'Cannot set build ('.$self->id.") status to '$status' because it does not have a master event."
        );
        return;
    }

    # Is it abandoned?
    if ( $build_event->event_status eq 'Abandoned' ) {
        $self->error_message(
            'Cannot set build ('.$self->id.") status to '$status' because the master event has been abandoned."
        );
        return;
    }

    # Set status and date completed
    $build_event->event_status($status);
    $build_event->date_completed( UR::Time->now ) if $set_date_completed;

    return $build_event;
}


sub abandon {
    my $self = shift;

    my $status = $self->status;
    if ($status && $status eq 'Abandoned') {
        return 1;
    }

    if ($status && ($status eq 'Running' || $status eq 'Scheduled')) {
        $self->stop;
    }

    # Abandon events
    $self->_abandon_events
        or return;

    # Reallocate - always returns true (legacy behavior)
    $self->reallocate;

    # FIXME Don't know if this should go here, but then we would have to call success and abandon through the model
    my $last_complete_build = $self->model->resolve_last_complete_build;
    if ( $last_complete_build and $last_complete_build->id eq $self->id ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), which should not return this build (".$self->id."), but did.");
        # FIXME soon - return here
        # return;
    }

    $self->add_note(
        header_text => 'Build Abandoned',
    );

    return 1;
}

sub _abandon_events { # does not realloc
    my $self = shift;

    my @events = sort { $b->id <=> $a->id } $self->events;
    for my $event ( @events ) {
        unless ( $event->abandon ) {
            $self->error_message(
                sprintf(
                    'Failed to abandon build (%s) because could not abandon event (%s).',
                    $self->id,
                    $event->id,
                )
            );
            return;
        }
    }

    return 1;
}

sub reports {
    my $self = shift;
    my $report_dir = $self->resolve_reports_directory;
    return unless -d $report_dir;
    return Genome::Report->create_reports_from_parent_directory($report_dir);
}

sub get_report {
    my ($self, $report_name) = @_;

    unless ( $report_name ) { # die?
        $self->error_message("No report name given to get report");
        return;
    }

    my $report_dir = $self->reports_directory.'/'.
    Genome::Report->name_to_subdirectory($report_name);
    return unless -d $report_dir;

    return Genome::Report->create_report_from_directory($report_dir); 
}

sub available_reports {
    my $self = shift;
    my $report_dir = $self->resolve_reports_directory;
    return unless -d $report_dir;
    return Genome::Report->create_reports_from_parent_directory($report_dir);
}

sub generate_send_and_save_report {
    my ($self, $generator_class, $additional_params) = @_;
    
    $additional_params ||= {};
    my $generator = $generator_class->create(
        build_id => $self->id,
        %$additional_params,
    );
    unless ( $generator ) {
        $self->error_message(
            sprintf(
                "Can't create report generator (%s) for build (%s)",
                $generator_class,
                $self->id
            )
        );
        return;
    }

    my $report = $generator->generate_report;
    unless ( $report ) {
        $self->error_message(
            sprintf("Can't generate report (%s) for build (%s)", $generator->name, $self->id)
        );
        return;
    }
    $self->add_report($report)
        or return;

    my $to = $self->_get_to_addressees_for_report_generator_class($generator_class);
    return 1 if not $to; # OK - do not send email
    
    my $email_confirmation = Genome::Report::Email->send_report(
        report => $report,
        to => $to,
        from => 'apipe@genome.wustl.edu',
        replyto => 'noreply@genome.wustl.edu',
        # maybe not the best/correct place for this information but....
        xsl_files => [ $generator->get_xsl_file_for_html ],
    );
    unless ( $email_confirmation ) {
        $self->error_message('Couldn\'t email build report ('.lc($report->name).')');
        return;
    }

    return $report;
}

sub _get_to_addressees_for_report_generator_class {
    my ($self, $generator_class) = @_;

    confess "No report generator class given to get 'to' addressees" unless $generator_class;

    my $user = $self->build_event->user_name;
    my $to = $user.'@genome.wustl.edu';

    # Do not send init and succ reports to apipe-builder
    if ( $user eq 'apipe-builder' and $generator_class ne 'Genome::Model::Report::BuildFailed' ) {
        return;
    }

    return $to;
}

sub report_generator_class_for_success { # in subclass replace w/ summary or the like?
    return 'Genome::Model::Report::BuildSucceeded';
}

#< SUBCLASSING >#
#
# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
    my $class = shift;

    my $type_name;
	if ( ref($_[0]) and $_[0]->isa(__PACKAGE__) ) {
		$type_name = $_[0]->model->type_name;
	}
    else {
        my ($bx,@extra) = $class->define_boolexpr(@_);
        my %params = ($bx->params_list, @extra);
        my $model_id = $params{model_id};
        my $model = Genome::Model->get($model_id);
        unless ($model) {
            return undef;
        }
        $type_name = $model->type_name;
    }

    unless ( $type_name ) {
        my $rule = $class->define_boolexpr(@_);
        $type_name = $rule->specified_value_for_property_name('type_name');
    }

    if (defined $type_name ) {
        my $subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
        my $sub_classification_method_name = $class->get_class_object->sub_classification_method_name;
        if ( $sub_classification_method_name ) {
            if ( $subclass_name->can($sub_classification_method_name)
                 eq $class->can($sub_classification_method_name) ) {
                return $subclass_name;
            } else {
                return $subclass_name->$sub_classification_method_name(@_);
            }
        } else {
            return $subclass_name;
        }
    } else {
        return undef;
    }
}

sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::Model::Build' , $subclass);
    return $class_name;

}

sub _resolve_type_name_for_class {
    my $class = shift;

    my ($subclass) = $class =~ /^Genome::Model::Build::([\w\d]+)$/;
    return unless $subclass;

    return lc join(" ", ($subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx));

    my @words = $subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx;
    return lc(join(" ", @words));
}

sub get_all_objects {
    my $self = shift;

    my $sorter = sub { # not sure why we sort, but I put it in a anon sub for convenience
        return unless @_;
        #if ( $_[0]->id =~ /^\-/) {
            return sort {$b->id cmp $a->id} @_;
            #} 
            #else {
            #return sort {$a->id cmp $b->id} @_;
            #}
    };

    return map { $sorter->( $self->$_ ) } (qw(events inputs metrics from_build_links to_build_links variants));
}

sub yaml_string {
    my $self = shift;
    my $string = YAML::Dump($self);
    for my $object ($self->get_all_objects) {
        $string .= YAML::Dump($object);
    }
    return $string;
}

sub add_to_build{
    my $self = shift;
    my (%params) = @_;
    my $build = delete $params{to_build};
    my $role = delete $params{role};
    $role||='member';
   
    $self->error_message("no to_build provided!") and die unless $build;
    my $from_id = $self->id;
    my $to_id = $build->id;
    unless( $to_id and $from_id){
        $self->error_message ( "no value for this build(from_build) id: <$from_id> or to_build id: <$to_id>");
        die;
    }
    my $reverse_bridge = Genome::Model::Build::Link->get(from_build_id => $to_id, to_build_id => $from_id);
    if ($reverse_bridge){
        my $string =  "A build link already exists for these two builds, and in the opposite direction than you specified:\n";
        $string .= "to_build: ".$reverse_bridge->to_build." (this build)\n";
        $string .= "from_build: ".$reverse_bridge->from_build." (the build you are trying to set as a 'to' build for this one)\n";
        $string .= "role: ".$reverse_bridge->role;
        $self->error_message($string);
        die;
    }
    my $bridge = Genome::Model::Build::Link->get(from_build_id => $from_id, to_build_id => $to_id);
    if ($bridge){
        my $string =  "A build link already exists for these two builds:\n";
        $string .= "to_build: ".$bridge->to_build." (the build you are trying to set as a 'to' build for this one)\n";
        $string .= "from_build: ".$bridge->from_build." (this build)\n";
        $string .= "role: ".$bridge->role;
        $self->error_message($string);
        die;
    }
    $bridge = Genome::Model::Build::Link->create(from_build_id => $from_id, to_build_id => $to_id, role => $role);
    return $bridge;
}

sub add_from_build { # rename "add an underlying build" or something...
    my $self = shift;
    my (%params) = @_;
    my $build = delete $params{from_build};
    my $role = delete $params{role};
    $role||='member';
   
    $self->error_message("no from_build provided!") and die unless $build;
    my $to_id = $self->id;
    my $from_id = $build->id;
    unless( $to_id and $from_id){
        $self->error_message ( "no value for this build(to_build) id: <$to_id> or from_build id: <$from_id>");
        die;
    }
    my $reverse_bridge = Genome::Model::Build::Link->get(from_build_id => $to_id, to_build_id => $from_id);
    if ($reverse_bridge){
        my $string =  "A build link already exists for these two builds, and in the opposite direction than you specified:\n";
        $string .= "to_build: ".$reverse_bridge->to_build." (the build you are trying to set as a 'from' build for this one)\n";
        $string .= "from_build: ".$reverse_bridge->from_build." (this build)\n";
        $string .= "role: ".$reverse_bridge->role;
        $self->error_message($string);
        die;
    }
    my $bridge = Genome::Model::Build::Link->get(from_build_id => $from_id, to_build_id => $to_id);
    if ($bridge){
        my $string =  "A build link already exists for these two builds:\n";
        $string .= "to_build: ".$bridge->to_build." (this build)\n";
        $string .= "from_build: ".$bridge->from_build." (the build you are trying to set as a 'from' build for this one)\n";
        $string .= "role: ".$bridge->role;
        $self->error_message($string);
        die;
    }
    $bridge = Genome::Model::Build::Link->create(from_build_id => $from_id, to_build_id => $to_id, role => $role);
    return $bridge;
}

sub delete {
    my $self = shift;

    # Abandon events
    $self->status_message("Abandoning events associated with build");
    unless ($self->_abandon_events) {
        $self->error_message(
            "Unable to delete build (".$self->id.") because the events could not be abandoned"
        );
        confess $self->error_message;
    }
    
    # Delete all associated objects
    $self->status_message("Deleting other objects associated with build");
    my @objects = $self->get_all_objects; # TODO this method name should be changed
    for my $object (@objects) {
        $object->delete;
    }

    # Deallocate build directory, which will also remove it (unless no commit is on)
    my $disk_allocation = $self->disk_allocation;
    if ($disk_allocation) {
        $self->status_message("Deallocating build directory");
        unless ($disk_allocation->deallocate) {
            $self->warning_message('Failed to deallocate disk space.');
        }
    }
    
    # FIXME Don't know if this should go here, but then we would have to call success and abandon through the model
    #  This works b/c the events are deleted prior to this call, so the model doesn't think this is a completed
    #  build
    my $last_complete_build = $self->model->resolve_last_complete_build;
    if ( $last_complete_build and $last_complete_build->id eq $self->id ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), which should not return this build (".$self->id."), but did.");
        # FIXME soon - return here
        # return;
    }

    return $self->SUPER::delete;
}

sub set_metric {
    my $self = shift;
    my $metric_name  = shift;
    my $metric_value = shift;

    my $metric = Genome::Model::Metric->get(build_id=>$self->id, name=>$metric_name);
    my $new_metric;
    if ($metric) {
        #delete an existing one and create the new one
        $metric->delete;
        $new_metric = Genome::Model::Metric->create(build_id=>$self->id, name=>$metric_name, value=>$metric_value);
    } else {
        $new_metric = Genome::Model::Metric->create(build_id=>$self->id, name=>$metric_name, value=>$metric_value);
    }
    
    return $new_metric->value;
}

sub get_metric {
    my $self = shift;
    my $metric_name = shift;

    my $metric = Genome::Model::Metric->get(build_id=>$self->id, name=>$metric_name);
    if ($metric) {
        return $metric->value;
    }
}

# Returns a list of files contained in the build's data directory
sub files_in_data_directory { 
    my $self = shift;
    my @files;
    find({
        wanted => sub {
            my $file = $File::Find::name;
            push @files, $file;
        },
        follow => 1, 
        follow_skip => 2, },
        $self->data_directory,
    );
    return \@files;
}

# Given a full path to a file, return a path relative to the build directory
sub full_path_to_relative {
    my ($self, $path) = @_;
    my $rel_path = $path;
    my $dir = $self->data_directory;
    $dir .= '/' unless substr($dir, -1, 1) eq '/';
    $rel_path =~ s/$dir//;
    $rel_path .= '/' if -d $path and substr($rel_path, -1, 1) ne '/';
    return $rel_path;
}

# Returns a list of files that should be ignored by the diffing done by compare_output
# Files should be relative to the data directory of the build and can contain regex.
# Override in subclasses!
sub files_ignored_by_diff {
    return ();
}

# Returns a list of directories that should be ignored by the diffing done by compare_output
# Directories should be relative to the data directory of the build and can contain regex.
# Override in subclasses!
sub dirs_ignored_by_diff {
    return ();
}

# A list of regexes that, when applied to file paths that are relative to the build's data
# directory, return only one result. This is useful for files that don't have consistent
# names between builds (for example, if they have the build_id embedded in them. Override
# in subclasses!
sub regex_files_for_diff {
    return ();
}

# A list of metrics that the differ should ignore. Some model/build types store information
# as metrics that need to be diffed. Override this in subclasses.
sub metrics_ignored_by_diff {
    return ();
}

# A list of file suffixes that require special treatment to diff. This should include those
# files that have timestamps or other changing fields in them that an md5sum can't handle.
# Each suffix should have a method called diff_<SUFFIX> that'll contain the logic.
sub special_suffixes {
    return qw(
        gz
    );
}

# Gzipped files contain the timestamp and name of the original file, so this prints
# the uncompressed file to STDOUT and pipes it to md5sum.
sub diff_gz {
    my ($self, $first_file, $second_file) = @_;
    my $first_md5 = `gzip -dc $first_file | md5sum`;
    my $second_md5 = `gzip -dc $second_file | md5sum`;
    return 1 if $first_md5 eq $second_md5;
    return 0;
}

# This method takes another build id and compares that build against this one. It gets
# a list of all the files in both builds and attempts to find pairs of corresponding
# files. The files/dirs listed in the files_ignored_by_diff and dirs_ignored_by_diff
# are ignored entirely, while files listed by regex_files_for_diff are retrieved
# using regex instead of a simple string eq comparison. 
sub compare_output {
    my ($self, $other_build_id) = @_;
    my $build_id = $self->build_id;
    confess "Require build ID argument!" unless defined $other_build_id;
    my $other_build = Genome::Model::Build->get($other_build_id);
    confess "Could not get build $other_build_id!" unless $other_build;

    unless ($self->model_id eq $other_build->model_id) {
        confess "Builds $build_id and $other_build_id are not from the same model!";
    }
    unless ($self->class eq $other_build->class) {
        confess "Builds $build_id and $other_build_id are not the same type!";
    }

    # Create hashes for each build, keys are paths relative to build directory and 
    # values are full file paths
    my (%file_paths, %other_file_paths);
    require Cwd;
    for my $file (@{$self->files_in_data_directory}) {
        $file_paths{$self->full_path_to_relative($file)} = Cwd::abs_path($file);
    }
    for my $other_file (@{$other_build->files_in_data_directory}) {
        $other_file_paths{$other_build->full_path_to_relative($other_file)} = Cwd::abs_path($other_file);
    }

    # Now cycle through files in this build's data directory and compare with 
    # corresponding files in other build's dir
    my %diffs;
    FILE: for my $rel_path (sort keys %file_paths) {
        my $abs_path = delete $file_paths{$rel_path};
        my $dir = $self->full_path_to_relative(dirname($abs_path));
       
        next FILE if -d $abs_path;
        next FILE if $rel_path =~ /server_location.txt/;
        next FILE if grep { $dir =~ /$_/ } $self->dirs_ignored_by_diff;
        next FILE if grep { $rel_path =~ /$_/ } $self->files_ignored_by_diff;

        # Gotta check if this file matches any of the supplied regex patterns. 
        # If so, find the one (and only one) file from the other build that 
        # matches the same pattern
        my ($other_rel_path, $other_abs_path);
        REGEX: for my $regex ($self->regex_files_for_diff) {
            next REGEX unless $rel_path =~ /$regex/;

            my @other_keys = grep { $_ =~ /$regex/ } sort keys %other_file_paths;
            if (@other_keys > 1) {
                $diffs{$rel_path} = "multiple files from $other_build_id matched file name pattern $regex\n" . join("\n", @other_keys);
                map { delete $other_file_paths{$_} } @other_keys;
                next FILE;
            }
            elsif (@other_keys < 1) {
                $diffs{$rel_path} = "no files from $other_build_id matched file name pattern $regex";
                next FILE;
            }
            else {
                $other_rel_path = shift @other_keys;
                $other_abs_path = delete $other_file_paths{$other_rel_path};
            }
        }

        # If file name doesn't match any regex, assume relative paths are the same
        unless (defined $other_rel_path and defined $other_abs_path) {
            $other_rel_path = $rel_path;
            $other_abs_path = delete $other_file_paths{$other_rel_path};
            unless (defined $other_abs_path) {
                $diffs{$rel_path} = "no file $rel_path from build $other_build_id";
                next FILE;
            }
        }
      
        # Check if the files end with a suffix that requires special handling. If not,
        # just do an md5sum on the files and compare
        my $diff_result = 0;
        my (undef, undef, $suffix) = fileparse($abs_path, $self->special_suffixes);
        my (undef, undef, $other_suffix) = fileparse($other_abs_path, $self->special_suffixes);
        if ($suffix ne '' and $other_suffix ne '' and $suffix eq $other_suffix) {
            my $method = "diff_$suffix";
            $method =~ s/\-/\_/; # replace dashes, can't declare a method w/ dashes
            $diff_result = $self->$method($abs_path, $other_abs_path);
        }
        else {
            my $file_md5 = Genome::Sys->md5sum($abs_path);
            my $other_md5 = Genome::Sys->md5sum($other_abs_path);
            $diff_result = ($file_md5 eq $other_md5);
        }

        unless ($diff_result) {
            $diffs{$rel_path} = "files $abs_path and $other_abs_path are not the same!";
        }
    }

    # Make sure the other build doesn't have any extra files
    for my $rel_path (sort keys %other_file_paths) {
        my $abs_path = delete $other_file_paths{$rel_path};
        my $dir = $self->full_path_to_relative(dirname($abs_path));
        next if -d $abs_path;
        next if grep { $dir =~ /$_/ } $self->dirs_ignored_by_diff;
        next if grep { $rel_path =~ /$_/ } $self->files_ignored_by_diff;
        $diffs{$rel_path} = "no file $rel_path from build $build_id";
    }

    # Now compare metrics of both builds
    my %metrics;
    map { $metrics{$_->name} = $_ } $self->metrics;
    my %other_metrics;
    map { $other_metrics{$_->name} = $_ } $other_build->metrics;

    METRIC: for my $metric_name (sort keys %metrics) {
        my $metric = $metrics{$metric_name};

        if ( grep { $metric_name =~ /$_/ } $self->metrics_ignored_by_diff ) {
            delete $other_metrics{$metric_name} if exists $other_metrics{$metric_name};
            next METRIC;
        }

        my $other_metric = delete $other_metrics{$metric_name};
        unless ($other_metric) {
            $diffs{$metric_name} = "no build metric with name $metric_name found for build $other_build_id";
            next METRIC;
        }

        my $metric_value = $metric->value;
        my $other_metric_value = $other_metric->value;
        unless ($metric_value eq $other_metric_value) {
            $diffs{$metric_name} = "metric $metric_name has value $metric_value for build $build_id and value " .
            "$other_metric_value for build $other_build_id";
            next METRIC;
        }
    }

    # Catch any extra metrics that the other build has
    for my $other_metric_name (sort keys %other_metrics) {
        $diffs{$other_metric_name} = "no build metric with name $other_metric_name found for build $build_id";
    }

    return %diffs;
}


sub snapshot_revision {
    my $self = shift;

    # Previously we just used UR::Util::used_libs_perl5lib_prefix but this did not
    # "detect" a software revision when using code from PERL5LIB or compile-time
    # lib paths. Since it is common for developers to run just Genome from a Git
    # checkout we really want to record what versions of UR, Genome, and Workflow
    # were used.

    my @orig_inc = @INC;
    my @libs = ($INC{'UR.pm'}, $INC{'Genome.pm'}, $INC{'Workflow.pm'});
    die $self->error_message('Did not find all three modules loaded (UR, Workflow, and Genome).') unless @libs == 3;

    # assemble list of "important" libs
    @libs = map { File::Basename::dirname($_) } @libs;
    push @libs, UR::Util->used_libs;

    # remove trailing slashes
    map { $_ =~ s/\/+$// } (@libs, @orig_inc);

    @libs = $self->_uniq(@libs);

    # preserve the list order as appeared @INC
    my @inc;
    for my $inc (@orig_inc) {
        push @inc, grep { $inc eq $_ } @libs;
    }

    @inc = $self->_uniq(@inc);

    # if the only path is like /gsc/scripts/opt/genome/snapshots/genome-1213/lib/perl then just call it genome-1213
    # /gsc/scripts/opt/genome/snapshots/genome-1213/lib/perl -> genome-1213
    # /gsc/scripts/opt/genome/snapshots/custom/genome-foo/lib/perl -> custom/genome-foo
    if (@inc == 1 and $inc[0] =~ /^\/gsc\/scripts\/opt\/genome\/snapshots\//) {
        $inc[0] =~ s/^\/gsc\/scripts\/opt\/genome\/snapshots\///;
        $inc[0] =~ s/\/lib\/perl$//;
    }

    return join(':', @inc);
}


sub _uniq {
    my $self = shift;
    my @list = @_;
    my %seen = ();
    my @unique = grep { ! $seen{$_} ++ } @list;
    return @unique;
}

sub input_differences_from_model {
    my $self = shift;

    my @build_inputs = $self->inputs;
    my @model_inputs = $self->model->inputs;

    #build a list of inputs to check against
    my %build_inputs;
    for my $build_input (@build_inputs) {
        $build_inputs{$build_input->name}{$build_input->value_class_name}{$build_input->value_id} = $build_input;
    }

    my @model_inputs_not_found;
    for my $model_input (@model_inputs) {
        my $build_input_found = delete($build_inputs{$model_input->name}{$model_input->value_class_name}{$model_input->value_id});

        unless ($build_input_found) {
            push @model_inputs_not_found, $model_input;
        }
    }

    my @build_inputs_not_found;
    for my $name (keys %build_inputs) {
        for my $value_class_name (keys %{ $build_inputs{$name} }) {
            for my $build_input_not_found (values %{ $build_inputs{$name}{$value_class_name} }) {
                my $value = $build_input_not_found->value;
                if($value and $value->isa('Genome::Model::Build') and $value->model and my ($model_input) = grep($_->value eq $value->model, @model_inputs_not_found) ) {
                    @model_inputs_not_found = grep($_ ne $model_input, @model_inputs_not_found);
                } else {
                    push @build_inputs_not_found, $build_input_not_found;
                }
            }
        }
    } 

    return (\@model_inputs_not_found, \@build_inputs_not_found);
}

sub build_input_differences_from_model {
    return @{ ($_[0]->input_differences_from_model)[1] };
}

sub model_input_differences_from_model {
    return @{ ($_[0]->input_differences_from_model)[0] };
}

#a cheap convenience method for views
sub delta_model_input_differences_from_model {
    my $self = shift;

    my ($model_inputs, $build_inputs) = $self->input_differences_from_model;
    my @model_inputs_to_include;
    for my $model_input (@$model_inputs) {
        unless( grep{ $_->name eq $model_input->name } @$build_inputs ) {
            push @model_inputs_to_include, $model_input;
        }
    }
    return @model_inputs_to_include;
}




sub all_allocations {
    my $self = shift;
    my @input_values = map { $_->value } $self->inputs;
    my @allocations;
    for my $object ($self, @input_values) {
        push @allocations, Genome::Disk::Allocation->get(owner_id => $object->id, owner_class_name => $object->class);
    }
    return @allocations;
}


1;
