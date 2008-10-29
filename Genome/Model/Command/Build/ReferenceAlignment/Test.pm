package Genome::Model::Command::Build::ReferenceAlignment::Test;

use strict;
use warnings;
use Carp;

use Genome;
use Genome::Model::Tools::Maq::CLinkage0_6_5;
use Genome::Model::Tools::Maq::MapSplit;
use Genome::RunChunk;

use File::Path;
use Test::More;

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless {}, $class;

    $self->{_model_name} = $args{model_name} ||
        confess("Must define model_name for test:  $!");
    $self->{_subject_name} = $args{subject_name} ||
        confess("Must define subject_name for test:  $!");
    $self->{_subject_type} = $args{subject_type} ||
        confess("Must define subject_type for test:  $!");
    $self->{_processing_profile_name} = $args{processing_profile_name} ||
        confess("Must define processing_profile_name for test:  $!");
    $self->{_auto_execute} = $args{auto_execute} || 0;
    if ($args{read_sets}) {
        my $read_sets = $args{read_sets};
        if (ref($read_sets) eq 'ARRAY') {
            $self->{_read_set_array_ref} = $read_sets;
        } else {
            confess('Supplied object type is '. ref($read_sets) ." and expected array ref:  $!");
        }
    } else {
        confess("Must define read_sets for test:  $!");
    }
    return $self;
}

sub auto_execute {
    my $self = shift;
    return $self->{_auto_execute};
}

sub add_directory_to_remove {
    my $self = shift;
    my $dir = shift;
    unless ($dir) {
        carp("No directory given to remove:  $!");
    }
    my @directories_to_remove;
    if ($self->{_dir_array_ref}) {
        my $dir_ref = $self->{_dir_array_ref};
        @directories_to_remove = @{$dir_ref};
    }
    push @directories_to_remove, $dir;
    $self->{_dir_array_ref} = \@directories_to_remove;
}


sub model {
    my $self = shift;
    if (@_) {
        my $object = shift;
        unless ($object->isa('Genome::Model')) {
            confess('expected Genome::Model and got '. $object->class ." object:  $!");
        }
        $self->{_model} = $object;
    }
    return $self->{_model};
}

sub build {
    my $self = shift;
    if (@_) {
        my $object = shift;
        unless ($object->isa('Genome::Model::Command::Build::ReferenceAlignment')) {
            confess('expected Genome::Model::Command::Build::ReferenceAlignment and got '. $object->class ." object:  $!");
        }
        $self->{_build} = $object;
    }
    return $self->{_build};
}

sub runtests {
    my $self = shift;

    my @tests = (
                 'startup',
                 'create_model',
                 'add_reads',
                 'schedule',
                 'run',
                 'remove_data',
             );
    for my $test (@tests) {
        $self->$test;
        if ($self->auto_execute) {
            if ($test eq 'schedule') {
                #shoul fix test number
                last;
            }
        }
    }
    return 1;
}

sub startup {
    my $self = shift;
    is(App::DB->db_access_level,'rw','App::DB db_access_level');
    ok(App::DB::TableRow->use_dummy_autogenerated_ids,'App::DB::TableRow use_dummy_autogenerated_ids');
    ok(App::DBI->no_commit,'App::DBI no_commit');
    ok($ENV{UR_DBI_NO_COMMIT},'environment variable UR_DBI_NO_COMMIT');
    SKIP: {
        skip 'using real ids with auto execute', 1 if $self->auto_execute;
        ok($ENV{UR_USE_DUMMY_AUTOGENERATED_IDS},'environment variable UR_USE_DUMMY_AUTOGENERATED_IDS');
    }
}


sub create_model {
    my $self = shift;
    my $create_command= Genome::Model::Command::Create::Model->create(
                                                                      model_name => $self->{_model_name},
                                                                      subject_name => $self->{_subject_name},
                                                                      subject_type => $self->{_subject_type},
                                                                      processing_profile_name => $self->{_processing_profile_name},
                                                                      bare_args => [],
                                                                  );

    isa_ok($create_command,'Genome::Model::Command::Create::Model');

    &_trap_messages($create_command);
    my $result = $create_command->execute();

    ok($result, 'execute genome-model create');
    my @status_messages = $create_command->status_messages();
    ok(scalar(grep { $_ eq 'created model '.$self->{'_model_name'} } @status_messages),
        'message mentioned creating the model');  # There may have been one there for creating a directory, too
    # FIXME commented out for now - there may have been a warning about an existing symlink
    # my @warning_messages = $create_command->warning_messages;
    #is(scalar(@warning_messages), 0, 'no warnings');
    my @error_messages = $create_command->error_messages;
    is(scalar(@error_messages), 0, 'no errors');

    my $genome_model_id = $result->id;

    my @models = Genome::Model->get($genome_model_id);
    is(scalar(@models),1,'expected one model');
    my $model = $models[0];
    $model->test(1);

    isa_ok($model,'Genome::Model');
    is($model->genome_model_id,$genome_model_id,'genome_model_id accessor');

    $self->add_directory_to_remove($model->data_directory);
    $self->model($model);
}

sub add_reads {
    my $self = shift;
    my $model = $self->model;
    isa_ok($model,'Genome::Model');
    my @read_sets = @{$self->{_read_set_array_ref}};
    for my $read_set (@read_sets) {
        isa_ok($read_set,'GSC::Sequence::Item');
        my $add_reads_command = Genome::Model::Command::AddReads->create(
                                                                         model_id => $model->id,
                                                                         read_set_id => $read_set->seq_id,
                                                                     );
        isa_ok($add_reads_command,'Genome::Model::Command::AddReads');
        ok($add_reads_command->execute(),'execute genome-model add-reads');
    }
}

sub schedule {
    my $self = shift;
    my $model = $self->model;
    my $build = Genome::Model::Command::Build::ReferenceAlignment->create(
                                                                          model_id => $model->id,
                                                                          auto_execute => $self->auto_execute,
                                                                          hold_run_jobs => $self->auto_execute,
                                                                      );
    isa_ok($build,'Genome::Model::Command::Build::ReferenceAlignment');

    # supress warning messages about obsolete locking
    Genome::Model::ReferenceAlignment->message_callback('warning', sub {});
    &_trap_messages($build);
    ok($build->execute(), 'execute genome-model build reference-alignment');

    my @status_messages = $build->status_messages();
    my @warning_messages = $build->warning_messages();
    my @error_messages = $build->error_messages();

    # FIXME This code is used in several different tests, each of which generate different numbers
    # of messages about scheduling...  Is there some other method of making sure the right
    # number of downstream events were scheduled?
    ok(scalar(grep { m/^Scheduling .* Genome::Model::ReadSet/} @status_messages),
       'Saw a message about ReadSet');
    ok(scalar(grep { m/^Scheduled Genome::Model::Command::Build::ReferenceAlignment::AssignRun/} @status_messages),
       'Saw a message about AssignRun');
    ok(scalar(grep { m/^Scheduled Genome::Model::Command::Build::ReferenceAlignment::AlignReads/} @status_messages),
       'Saw a messages about  AlignReads');
    ok(scalar(grep { m/^Scheduled Genome::Model::Command::Build::ReferenceAlignment::ProcessLowQualityAlignments/} @status_messages),
       'Saw a message about ProcessLowQualityAlignments');
    is(scalar(grep { m/^Scheduling .* reference_sequence/} @status_messages),
       3, 'Got 3 reference_sequence messages');
    is(scalar(grep { m/^Scheduled Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments/} @status_messages),
       3, 'Got 3 MergeAlignments messages');
    is(scalar(grep { m/^Scheduled Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype/} @status_messages),
       3, 'Got 3 UpdateGenotype messages');
    is(scalar(grep { m/^Scheduled Genome::Model::Command::Build::ReferenceAlignment::FindVariations/} @status_messages),
       3, 'Got 3 FindVariations messages');
    is(scalar(grep { m/^Scheduled Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations/} @status_messages),
       3, 'Got 3 PostprocessVariations messages');
    is(scalar(grep { m/^Scheduled Genome::Model::Command::Build::ReferenceAlignment::AnnotateVariations/} @status_messages),
       3, 'Got 3 AnnotateVariations messages');
    # Not checking warning messages - for now, there are some relating to obsolete locking
    is(scalar(@error_messages), 0, 'no errors');

    $self->build($build);
}

sub run {
    my $self = shift;
    my $model = $self->model;
    my $build = $self->build;
    my @events;
    for my $stage_name ($build->stages) {
        my @classes = $build->classes_for_stage($stage_name);
$DB::single=1;
        push @events, $self->run_events_for_class_array_ref(\@classes);
    }
    my @failed_events = grep { $_->event_status ne 'Succeeded' } @events;
    my $build_status;
    if (@failed_events) {
        $build_status = 'Failed';
        diag("FAILED " . $build->command_name .' found '. scalar(@failed_events) .' incomplete events');
    } else {
        $build_status = 'Succeeded';
    }
    set_event_status($build,$build_status);
    is($build->event_status,$build_status,'the build status was set correctly after execution of the events');
    return @events;
}

sub run_events_for_class_array_ref {
    my $self = shift;
    my $classes = shift;
    my @read_sets = @{$self->{_read_set_array_ref}};
    my $build = $self->build;
    my @stages = $build->stages;
    my $stage2 = $stages[1];
    my $stage_object_method = $stage2 .'_objects';
    my @stage2_objects = $build->$stage_object_method;
    my @events;
    for my $command_class (@$classes) {
        if (ref($command_class) eq 'ARRAY') {
            push @events, $self->run_events_for_class_array_ref($command_class);
        } else {
            my @events = $command_class->get(model_id => $self->model->id);
            @events = sort {$b->genome_model_event_id <=> $a->genome_model_event_id} @events;
            if ($command_class->isa('Genome::Model::EventWithReadSet')) {
                is(scalar(@events),scalar(@read_sets),'the number of events matches read sets for EventWithReadSet class '. $command_class);
            } elsif ($command_class->isa('Genome::Model::EventWithRefSeq')) {
                is(scalar(@events),scalar(@stage2_objects),'the number of events matches ref seqs for EventWithRefSeq class '. $command_class);
            } else {
                is(scalar(@events),1,'Only expecting one event when for class '. $command_class);
            }
            for my $event (@events) {
                $self->execute_event_test($event);
            }
        }
    }
    return @events;
}

sub execute_event_test  {
    my ($self,$event) = @_;

    my $event_model = $event->model;
    $event_model->test(1);
    is($self->model->id,$event_model->id,'genome-model id comparison');

    SKIP: {
          skip 'AnnotateVariations takes too long', 1 if $event->isa('Genome::Model::Command::Build::ReferenceAlignment::AnnotateVariations');
          # FIXME - some of these events emit messages of one kind or another - are any
          # of them worth looking at?
          &_trap_messages($event);
          my $result = $event->execute();

          ok($result,'Execute: '. $event->command_name);
          if ($result) {
              set_event_status($event,'Succeeded');
          }
          else {
              diag("FAILED " . $event->command_name . " " . $event->error_message());
              set_event_status($event,'Failed');
          }
        SKIP: {
              skip 'class '. $event->class .' does not have a verify_successful_completion method', 1 if !$event->can('verify_successful_completion');
              ok($event->verify_successful_completion,'verify_successful_completion for class '. $event->class);
          }
      }
}

sub set_event_status {
    my ($event,$status) = @_;
    my $now = UR::Time->now;
    $event->event_status($status);
    $event->date_completed($now);
}

sub remove_data {
    my $self = shift;

    my $model = $self->model;
    my @data_dirs = map { $_->full_path }
        grep { defined($_->full_path) }
            $model->read_sets;
    my @alignment_events = $model->alignment_events;
    my @alignment_dirs = map { $_->read_set_link->read_set_alignment_directory } @alignment_events;
    my $archive_file = $model->resolve_archive_file;

    # FIXME - the delete below causes a lot of warning messages about deleting
    # hangoff data.  do we need to check the contents?
    &_trap_messages('Genome::Model::Event');
    &_trap_messages('Genome::Model::Command::AddReads');  # Why didn't the above catch these, too?
    ok($self->model->delete,'successfully removed model');
    ok(unlink($archive_file),'successfully unlinked archive file');
    my $directories_to_remove = $self->{_dir_array_ref};
    #print "Removing directories:\n";
    for my $directory_to_remove (@$directories_to_remove, @alignment_dirs, @data_dirs) {
        #print $directory_to_remove . "\n";
        rmtree $directory_to_remove;
    }
}


sub create_test_pp {
    my $self = shift;

    my %processing_profile = @_;
    $processing_profile{bare_args} = [];
    my $create_pp_command = Genome::Model::Command::Create::ProcessingProfile::ReferenceAlignment->create(%processing_profile);
    unless($create_pp_command->execute()) {
        confess("Failed to create processing_profile for test:  $!");
    }
    return 1;
}


sub _trap_messages {
    my $obj = shift;

    $obj->dump_error_messages(0);
    $obj->dump_warning_messages(0);
    $obj->dump_status_messages(0);
    $obj->queue_error_messages(1);
    $obj->queue_warning_messages(1);
    $obj->queue_status_messages(1);
}

1;
