package Genome::Model::Build;

use strict;
use warnings;

use Genome;

use Carp;
use Data::Dumper 'Dumper';
use File::Path;
use Regexp::Common;
use Workflow;
use YAML;

class Genome::Model::Build {
    table_name => 'GENOME_MODEL_BUILD',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        build_id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        data_directory      => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
        #< Model and props via model >#
        model               => { is => 'Genome::Model', id_by => 'model_id' },
        model_id            => { is => 'NUMBER', len => 10, implied_by => 'model', constraint_name => 'GMB_GMM_FK' },
        model_name          => { via => 'model', to => 'name' },
        type_name           => { via => 'model' },
        subject_id          => { via => 'model' },
        subject_name        => { via => 'model' },
        processing_profile  => { via => 'model' },
        processing_profile_name => { via => 'model' },
        #<>#
        #< Events >#
        the_events          => { is => 'Genome::Model::Event', reverse_as => 'build', is_many => 1,  },
        the_events_statuses => { via => 'the_events', to => 'event_status' },
        the_master_event    => { via => 'the_events', to => '-filter', where => [event_type => 'genome model build'] },
        run_by              => { via => 'the_master_event', to => 'user_name' },
        status              => { via => 'the_master_event', to => 'event_status' },
        master_event_status => { via => 'the_master_event', to => 'event_status' }, # this name is has an inside framing instead of outside
    ],
    has_optional => [
        disk_allocation     => {
                                calculate_from => [ 'class', 'id' ],
                                calculate => q|
                                    my $disk_allocation = Genome::Disk::Allocation->get(
                                                          owner_class_name => $class,
                                                          owner_id => $id,
                                                      );
                                    return $disk_allocation;
                                |,
        },
        software_revision   => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
    ],
    has_many_optional => [
    #< Inputs >#
    inputs => {
        is => 'Genome::Model::Build::Input',
        reverse_as => 'build',
        doc => 'Inputs assigned to the model when the build was created.'
    },
    instrument_data => {
        is => 'Genome::InstrumentData',
        via => 'inputs',
        is_mutable => 1,
        is_many => 1,
        where => [ name => 'instrument_data' ],
        to => 'value',
        doc => 'Instrument data assigned to the model when the build was created.'
    },
    #<>#
    from_build_links                  => { is => 'Genome::Model::Build::Link',
        reverse_id_by => 'to_build',
        doc => 'bridge table entries where this is the "to" build(used to retrieve builds this build is "from")'
    },
    from_builds                       => { is => 'Genome::Model::Build',
        via => 'from_build_links', to => 'from_build',
        doc => 'Genome builds that contribute "to" this build',
    },
    to_build_links                    => { is => 'Genome::Model::Build::Link',
        reverse_id_by => 'from_build',
        doc => 'bridge entries where this is the "from" build(used to retrieve builds builds this build is "to")'
    },
    to_builds                       => { is => 'Genome::Model::Build',
        via => 'to_build_links', to => 'to_build',
        doc => 'Genome builds this build contributes "to"',
    },
    attributes                        => { is => 'Genome::MiscAttribute', reverse_id_by => '_build', where => [ entity_class_name => 'Genome::Model::Build' ] },
    metrics                           => { is => 'Genome::Model::Metric', reverse_id_by => 'build', doc => "Build metrics"},
    variants                          => { is => 'Genome::Model::BuildVariant', reverse_id_by => 'build', 
                                           doc => "variants linked to this build... currently only for Somatic builds but need this accessor for get_all_objects"},
    ], 

    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my ($class, %params) = @_;

    # model
    unless ( $class->_validate_model_id($params{model_id}) ) {
        $class->delete;
        return;
    }

    # create
    my $self = $class->SUPER::create(%params)
        or return;


    # inputs
    unless ( $self->_copy_model_inputs ) {
        $self->delete;
        return;
    }

    # data directory
    unless ($self->data_directory) {
        my $dir;
        eval {
            $dir = $self->resolve_data_directory;
        };
        if ($@) {
            $self->delete;
            return;
        }
        $self->data_directory($dir);
    }

    return $self;
}

sub _validate_model_id {
    my ($class, $model_id) = @_;

    unless ( defined $model_id ) {
        $class->error_message("No model id given to get model of build.");
        return;
    }

    unless ( $model_id =~ /^$RE{num}{int}$/ ) {
        $class->error_message("Model id ($model_id) is not an integer.");
        return;
    }

    unless ( Genome::Model->get($model_id) ) {
        $class->error_message("Can't get model for id ($model_id).");
        return;
    }
    
    return 1;
}

sub _copy_model_inputs {
    my $self = shift;

    # Create gets called twice, calling this method twice, so
    #  gotta check if we added the inputs already (and crashes). 
    #  I tried to figure out how to stop create being called twice, but could not.
    my @inputs = $self->inputs;
    return 1 if @inputs;

    $DB::single = 1;
    for my $input ( $self->model->inputs ) {
        my %params = map { $_ => $input->$_ } (qw/ name value_class_name value_id /);
        unless ( $self->add_input(%params) ) {
            $self->error_message("Can't copy model input to build: ".Data::Dumper::Dumper(\%params));
            return;
        }
    }

    # FIXME temporary - copy model instrument data as inputs, when all 
    #  inst_data is an input, this can be removed
    my @existing_inst_data = $self->instrument_data;
    my @model_inst_data = $self->model->instrument_data;
    for my $inst_data ( @model_inst_data ) {
        # We may have added the inst data when adding the inputs
        # Adding as input cuz of mock inst data
        #print Data::Dumper::Dumper($inst_data);
        next if grep { $inst_data->id eq $_->id } @existing_inst_data;
        my %params = (
            name => 'instrument_data',
            value_class_name => $inst_data->class,
            value_id => $inst_data->id,
        );
        unless ( $self->add_input(%params) ) {
            $self->error_message("Can't add instrument data (".$inst_data->id.") to build.");
            return;
        }
    }

    return 1;

}
#<>#

#< Inputs >#
sub instrument_data_assignments {
    my $self = shift;
    my @idas = Genome::Model::InstrumentDataAssignment->get(
        model_id => $self->model_id,
        first_build_id => {
            operator => '<=',
            value => $self->build_id,
        },
    );
    return @idas;
    #my $model = $self->model;
    #my @model_idas = $model->instrument_data_assignments;
    #When a build was deleted the first_build_id was set to null, this bug has been corrected however...
    #my @null_idas = grep { (!defined($_->first_build_id)) } @model_idas;
    #if (@null_idas) {
    #    $self->warning_message('There are undefined first_build_ids for build '. $self->build_id .'! YOU SHOULD START A NEW BUILD.');
    #}
    #my @build_idas = grep { (!defined($_->first_build_id)) || ($_->first_build_id <= $self->build_id) } @model_idas;
    #return @build_idas;
}

sub instrument_data_count { # FIXME for inputs
    return scalar( $_[0]->instrument_data_assignments );
}
#<>#

#< Events >#
sub events {
    my $self = shift;

    my @events = Genome::Model::Event->get(
        model_id => $self->model_id,
        build_id => $self->build_id,
    );
    return @events;
}

sub build_events {
    my $self = shift;

    my @build_events = Genome::Model::Event::Build->get(
        model_id => $self->model_id,
        build_id => $self->build_id,
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

sub workflow_instances {
    my $self = shift;
    
    my @instances = Workflow::Store::Db::Operation::Instance->get(
        name => $self->build_id . ' all stages'
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

sub build_status {
    my $self = shift;

    my $build_event = $self->build_event;
    unless ($build_event) {
        return;
    }
    return $build_event->event_status;
}

sub date_scheduled {
    my $self = shift;

    my $build_event = $self->build_event;
    unless ($build_event) {
        return;
    }
    return $build_event->date_scheduled;
}

sub date_completed {
    my $self = shift;

    my $build_event = $self->build_event;
    unless ($build_event) {
        return;
    }
    return $build_event->date_completed;
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
    return 512000;
}

sub resolve_data_directory {
    my $self = shift;
    my $model = $self->model;
    my $data_directory = $model->data_directory;
    my $build_subdirectory = '/build'. $self->build_id;
    if ($data_directory =~ /\/gscmnt\/.*\/info\/(medseq\/)?(.*)/) {
        my $allocation_path = $2;
        $allocation_path .= $build_subdirectory;
        my $kb_requested = $self->calculate_estimated_kb_usage;
        if ($kb_requested) {
            my $disk_allocation = Genome::Disk::Allocation->allocate(
                                                                     disk_group_name => 'info_genome_models',
                                                                     allocation_path => $allocation_path,
                                                                     kilobytes_requested => $kb_requested,
                                                                     owner_class_name => $self->class,
                                                                     owner_id => $self->id,
                                                                 );
            unless ($disk_allocation) {
                $self->error_message('Failed to get disk allocation');
                $self->delete;
                die $self->error_message;
            }
            my $build_symlink = $data_directory . $build_subdirectory;
            unlink $build_symlink if -e $build_symlink;
            my $build_data_directory = $disk_allocation->absolute_path;
            unless (Genome::Utility::FileSystem->create_directory($build_data_directory)) {
                $self->error_message("Failed to create directory '$build_data_directory'");
                die $self->error_message;
            }
            unless (Genome::Utility::FileSystem->create_symlink($build_data_directory,$build_symlink)) {
                $self->error_message("Failed to make symlink '$build_symlink' with target '$build_data_directory'");
                die $self->error_message;
            }
            return $build_data_directory;
        }
    }
    return $data_directory . $build_subdirectory;
}

#< Disk Allocation >#
sub allocate {
    # FIXME - move the logic above to here
}

sub reallocate {
    my $self = shift;

    my $disk_allocation = $self->disk_allocation
        or return 1; # ok - may not have an allocation

    unless ($disk_allocation->reallocate) {
        $self->warning_message('Failed to reallocate disk space.');
    }

    return 1;
}


#< Log >#
sub log_directory { 
    return  $_[0]->data_directory . '/logs/';
}

#< Reports >#
sub reports_directory { 
    return  $_[0]->data_directory . '/reports/';
}
sub resolve_reports_directory { return reports_directory(@_); }

sub add_report {
    my ($self, $report) = @_;

    my $directory = $self->resolve_reports_directory;
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
        unless (Genome::Utility::FileSystem->create_directory($directory)) {
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

#< Build Actions >#
sub schedule {
    my $self = shift;

    if ( my $existing_build_event = $self->build_event ) {
        $self->error_message(
            "Can't schedule this build (".$self->id."), it a already has a main build event: ".
            Data::Dumper::Dumper($existing_build_event)
        );
        return;
    }

    $self->software_revision(UR::Util::used_libs_perl5lib_prefix());
    
    Genome::Utility::FileSystem->create_directory( $self->data_directory )
        or return;
    Genome::Utility::FileSystem->create_directory( $self->log_directory )
        or return;

    my $build_event = Genome::Model::Event::Build->create(
        model_id => $self->model->id,
        build_id => $self->id,
        event_type => 'genome model build',
    );
    unless ( $build_event ) {
        $self->error_message( 
            sprintf("Can't create build for model (%s %s)", $self->model->id, $self->model->name) 
        );
        $self->delete;
        return;
    }
    $build_event->schedule; # in G:M:Event, sets status, times, etc.

    my @stages; 
    for my $stage_name ( $self->processing_profile->stages ) {
        # FIXME why are we attempting to schedule stages that have no classes??
        my @events = $self->_schedule_stage($stage_name);
        unless ( @events ) {
            $self->error_message('WARNING: Stage '. $stage_name .' for build ('. $self->build_id .") failed to schedule objects for classes:\n".
                join("\n",$self->processing_profile->classes_for_stage($stage_name)));
            next;
        }
        push @stages, { name => $stage_name, events => \@events };
    }
    
    return \@stages;
}

sub _schedule_stage {
    my ($self, $stage_name) = @_;

    my $pp = $self->processing_profile;
    my @objects = $pp->objects_for_stage($stage_name, $self->model);
    my @events;
    foreach my $object (@objects) {
        my $object_class;
        my $object_id; 
        if (ref($object)) {
            $object_class = ref($object);
            $object_id = $object->id;
        } elsif ($object eq '1') {
            $object_class = 'single_instance';
        } else {
            $object_class = 'reference_sequence';
            $object_id = $object;
        }

        # Putting status message on build event because some tests expect it.  
        #  Prolly can (re)move this to somewhere...
        if ($object_class->isa('Genome::InstrumentData')) {
            $self->status_message('Scheduling jobs for '
                . $object_class . ' '
                . $object->full_name
                . ' (' . $object->id . ')'
            );
        } elsif ($object_class eq 'reference_sequence') {
            $self->status_message('Scheduling jobs for reference sequence ' . $object_id);
        } elsif ($object_class eq 'single_instance') {
            $self->status_message('Scheduling '. $object_class .' for stage '. $stage_name);
        } else {
            $self->status_message('Scheduling for '. $object_class .' with id '. $object_id);
        }
        my @command_classes = $pp->classes_for_stage($stage_name);
        push @events, $self->_schedule_command_classes_for_object($object,\@command_classes);
    }

    return @events;
}

sub _schedule_command_classes_for_object {
    my $self = shift;
    my $object = shift;
    my $command_classes = shift;
    my $prior_event_id = shift;

    my @scheduled_commands;
    for my $command_class (@{$command_classes}) {
        if (ref($command_class) eq 'ARRAY') {
            push @scheduled_commands, $self->_schedule_command_classes_for_object($object,$command_class,$prior_event_id);
        } else {
            if ($command_class->can('command_subclassing_model_property')) {
                my $subclassing_model_property = $command_class->command_subclassing_model_property;
                unless ($self->model->$subclassing_model_property) {
                    # TODO: move into the creation of the processing profile
                    #$self->status_message("This processing profile doesNo value defined for $subclassing_model_property in the processing profile.  Skipping related processing...");
                    next;
                }
            }
            my $command;
            if ($command_class =~ /MergeAlignments|UpdateGenotype|FindVariations/) {
                if (ref($object)) {
                    unless ($object->isa('Genome::Model::RefSeq')) {
                        my $error_message = 'Expecting Genome::Model::RefSeq for EventWithRefSeq but got '. ref($object);
                        $self->error_message($error_message);
                        die;
                    }
                    $command = $command_class->create(
                        model_id => $self->model_id,
                        ref_seq_id => $object->ref_seq_id,
                    );
                } else {
                    $command = $command_class->create(
                        model_id => $self->model_id,
                        ref_seq_id => $object,
                    );
                }
            } elsif ($command_class =~ /AlignReads|TrimReadSet|AssignReadSetToModel|AddReadSetToProject|FilterReadSet/) {
                if ($object->isa('Genome::InstrumentData')) {
                    my $ida = Genome::Model::InstrumentDataAssignment->get(
                        model_id => $self->model_id,
                        instrument_data_id => $object->id,
                    );
                    unless ($ida) {
                        #This seems like duplicate logic but works best for the mock models in test case
                        my $model = $self->model;
                        ($ida) = grep { $_->instrument_data_id == $object->id} $model->instrument_data_assignments;
                        unless ($ida) {
                            $self->error_message('Failed to find InstrumentDataAssignment for instrument data '. $object->id .' and model '. $self->model_id);
                            die $self->error_message;
                        }
                    }
                    unless ($ida->first_build_id) {
                        $ida->first_build_id($self->build_id);
                    }
                    $command = $command_class->create(
                        instrument_data_id => $object->id,
                        model_id => $self->model_id,
                    );
                } else {
                    my $error_message = 'Expecting Genome::InstrumentData object but got '. ref($object);
                    $self->error_message($error_message);
                    die;
                }
            } elsif ($command_class->isa('Genome::Model::Event')) {
                $command = $command_class->create(
                    model_id => $self->model_id,
                );
            }
            unless ($command) {
                my $error_message = 'Problem creating subcommand for class '
                . ' for object class '. ref($object)
                . ' model id '. $self->model_id
                . ': '. $command_class->error_message();
                $self->error_message($error_message);
                die;
            }
            $command->build_id($self->build_id);
            $command->prior_event_id($prior_event_id);
            $command->schedule;
            $prior_event_id = $command->id;
            push @scheduled_commands, $command;
            my $object_id;
            if (ref($object)) {
                $object_id = $object->id;
            } else {
                $object_id = $object;
            }
            $self->status_message('Scheduled '. $command_class .' for '. $object_id
                .' event_id '. $command->genome_model_event_id ."\n");
        }
    }
    return @scheduled_commands;
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

    $self->_verify_build_is_not_abandoned_and_set_status_to('Failed', 1)
        or return;
   
    $self->generate_send_and_save_report(
        'Genome::Model::Report::BuildFailed', {
            errors => \@errors,
        },
    )
        or return;

    return 1;
}

sub success {
    my $self = shift;

    # set status
    $self->_verify_build_is_not_abandoned_and_set_status_to('Succeeded', 1)
        or return;

    # report - if this fails set status back to Running, then the workflow will fail it
    unless ( $self->generate_send_and_save_report( $self->report_generator_class_for_success ) ) {
        $self->_verify_build_is_not_abandoned_and_set_status_to('Running');
        return;
    }

    # reallocate - always returns true (legacy behavior)
    return $self->reallocate; 
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

# abandon
sub abandon {
    my $self = shift;

    # Abandon events
    $self->_abandon_events
        or return;

    # Reallocate - always returns true (legacy behavior)
    $self->reallocate;

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

#< Reports >#
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
    
    my $to = $self->_get_to_addressees_for_report_generator_class($generator_class)
        or return;
    
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

    $self->add_report($report)
        or return;

    return $report;
}

sub _get_to_addressees_for_report_generator_class {
    my ($self, $generator_class) = @_;

    confess "No report generator class given to get 'to' addressees" unless $generator_class;

    my $user = $self->build_event->user_name;
    # Send reports to user unless it's apipe
    unless ( $user eq 'apipe' ) {
        return $self->build_event->user_name.'@genome.wustl.edu';
    }

    # Send failed reports to bulk
    return 'apipe-bulk@genome.wustl.edu' if $generator_class eq 'Genome::Model::Report::BuildFailed';

    # Send others to run
    return 'apipe-run@genome.wustl.edu';
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
        my %params = @_;
        my $model_id = $params{model_id};
        my $model = Genome::Model->get($model_id);
        unless ($model) {
            return undef;
        }
        $type_name = $model->type_name;
    }

    unless ( $type_name ) {
        my $rule = $class->get_rule_for_params(@_);
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

    return map { $sorter->( $self->$_ ) } (qw/ events inputs metrics from_build_links to_build_links variants/);
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

sub add_from_build{
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

#< Delete >#
sub delete {
    my $self = shift;

    # Abandon
    unless ( $self->_abandon_events ) {
        $self->error_message(
            "Unable to delete build (".$self->id.") because the events could not be abandoned"
        );
        return;
    }
    
    # Delete all associated objects
    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        $object->delete;
    }

    # Re-point instrument data assigned first on this build to the next build.
    my ($next_build,@subsequent_builds) = Genome::Model::Build->get(
        model_id => $self->model_id,
        id => {
            operator => '>',
            value => $self->build_id,
        },  
    );
    my $next_build_id = ($next_build ? $next_build->id : undef);
    my @idas_fix = Genome::Model::InstrumentDataAssignment->get(
        model_id => $self->model_id,
        first_build_id => $self->build_id
    );
    for my $idas (@idas_fix) {
        $idas->first_build_id($next_build_id);
    }

    #my @idas = $self->instrument_data_assignments;
    #for my $ida (@idas) {
    #    $ida->first_build_id(undef);
    #}
    #
    if ($self->data_directory && -e $self->data_directory) {
        unless (rmtree $self->data_directory) {
            $self->warning_message('Failed to rmtree build data directory '. $self->data_directory);
        }
    }
    my $disk_allocation = $self->disk_allocation;
    if ($disk_allocation) {
        unless ($disk_allocation->deallocate) {
             $self->warning_message('Failed to deallocate disk space.');
        }
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


package Genome::Model::Build::AbstractBaseTest;

class Genome::Model::Build::AbstractBaseTest {
    is => 'Genome::Model::Build',
};

1;
