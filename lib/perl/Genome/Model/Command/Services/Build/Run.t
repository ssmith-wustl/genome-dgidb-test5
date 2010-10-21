#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

######

package Genome::Model::Command::Services::Build::Run::Test;

use base 'Genome::Utility::TestCommandBase';

use Genome::Model::Test;
use Genome::Utility::TestBase;
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Services::Build::Run';
}

sub _model {
    unless ( $_[0]->{_model} ) { die "No mock model was created" }
    return $_[0]->{_model};
}

sub _build {
    return $_[0]->_model->build;
}

sub startup : Tests(startup => 3) {
    my $self = shift;

    my $model = Genome::Model::Test->create_basic_mock_model(
        type_name => 'tester',
    ) or die "Can't create mock model";
    ok($model, 'Created mock model');
    $self->{_model} = $model;

    my $build = Genome::Model::Test->add_mock_build_to_model($model)
        or die "Can't create mock build";
    ok($build, 'Created mock build');
    $model->set_always('build', $build);
    $build->mock('initialize', sub{ 
            note("Build initialized!"); return 1;
            $build->build_event->event_status('Initialized');
        } );
    $self->_mock_build_success;
    $self->_mock_build_fail;

    # wf stuff
    $build->mock('newest_workflow_instance', sub{ return undef; } );
    *Workflow::Simple::run_workflow_lsf = sub{ return 1; }; 
    #*Workflow::Simple::resume_lsf = sub{ return 1; };
    # Run is just a wrapper around a workflow engine, we can make 
    #  it run any xml as an adequite test for now
    my $xml_file = $build->data_directory.'/build.xml';
    {
        my $w = Workflow::Model->create(
            name => 'container',
            input_properties => [ 'prior_result'],
            output_properties => [ 'result' ]
        );

        my $i = $w->get_input_connector;
        my $o = $w->get_output_connector;

        $w->add_link(
            left_operation => $i,
            left_property => 'prior_result',
            right_operation => $o,
            right_property => 'result'
        );

        $w->save_to_xml(OutputFile => $xml_file);
    }
    ok(-f $xml_file, "xml file '$xml_file' exists");

    return 1;
}

sub valid_param_sets {
    return (
        { # successful wf 
            model_id => $_[0]->_model->id,
            build_id => $_[0]->_build->id,
            after_execute => sub{
                my ($self, $obj, $param_set) = @_;
                is($self->_build->status, 'Succeeded', 'Build status is succeeded');
                return 1;
            },
        },
        { # successful wf then success fails
            model_id => $_[0]->_model->id,
            build_id => $_[0]->_build->id,
            before_execute => sub{
                my ($self, $obj, $param_set) = @_;
                $self->_mock_build_success_to_fail;
                return 1;
            },
            after_execute => sub{
                my ($self, $obj, $param_set) = @_;
                is($self->_build->status, 'Failed', 'Build status is failed');
                $self->_mock_build_success; # reset to be ok
                return 1;
            },
        },
        #
        # From this point on, wf will fail, unless changed!
        #
        { # failed wf w/o errors
            model_id => $_[0]->_model->id,
            build_id => $_[0]->_build->id,
            before_execute => sub{
                *Workflow::Simple::run_workflow_lsf = sub{ return; };
                return 1;
            },
            after_execute => sub{
                my ($self, $obj, $param_set) = @_;
                is($self->_build->status, 'Failed', 'Build status is failed');
                return 1;
            },
        },
        { # failed wf w/ errors
            model_id => $_[0]->_model->id,
            build_id => $_[0]->_build->id,
            before_execute => sub{
                *Workflow::Simple::run_workflow_lsf = sub{ return; };
                @Workflow::Simple::ERROR = ( _create_mock_wf_error() );
                return 1;
            },
            after_execute => sub{
                my ($self, $obj, $param_set) = @_;
                is($self->_build->status, 'Failed', 'Build status is failed');
                return 1;
            },
        },
        { # failed wf then fail fails
            model_id => $_[0]->_model->id,
            build_id => $_[0]->_build->id,
            before_execute => sub{
                my ($self, $obj, $param_set) = @_;
                $self->_mock_build_fail_to_fail;
                return 1;
            },
            after_execute => sub{
                my ($self, $obj, $param_set) = @_;
                is($self->_build->status, 'Failed', 'Build status is failed');
                $self->_mock_build_fail; # reset to be ok
                return 1;
            },
        },
    );
}

sub _invalid_param_sets {
    return (
    );
}

#< Build Status Method Mocking>#
sub _mock_build_success {
    my $self = shift;

    $self->_build->mock('success', sub{ 
            note("Build succeeded!"); 
            $self->_build->build_event->event_status('Succeeded');
            return 1; 
        } );

    return 1;
}

sub _mock_build_success_to_fail {
    my $self = shift;

    $self->_build->mock('success', sub{ 
            #note("Build succeeded, but is gonna fail now..."); 
            $self->_build->error_message("Build succeeded, but is gonna fail now..."); 
            return; 
        } );

    return 1;
}
sub _mock_build_fail {
    my $self = shift;

    $self->_build->mock('fail', sub{ 
            note("Build failed!"); 
            $self->_build->build_event->event_status('Failed');
            return 1; 
        } );

    return 1;
}

sub _mock_build_fail_to_fail {
    my $self = shift;

    $self->_build->mock('fail', sub{ 
            #note("Build failed, but is gonna fail the fail now..."); 
            $self->_build->error_message("Build failed, but is gonna fail the fail now..."); 
            $self->_build->build_event->event_status('Failed');
            return; 
        } );

    return 1;
}

#<>#
sub _create_mock_wf_error {
    return Genome::Utility::TestBase->create_mock_object(
        class => 'Workflow::Operation::InstanceExecution::Error',
        # STEP EVENT_ID  
        name => 'trim-and-screen 97901040',
        # BUILD_EVEVNT_ID STAGE/STEP EVENT_ID  
        path_name => '97901036 all stages/97901036 assemble/trim-and-screen 97901040',
        _build_path_string=> '97901036 all stages/97901036 assemble/trim-and-screen 97901040',
        # LSF_JOB_ID maybe undef
        dispatch_identifier => 1000002,
        # ERROR_STRING
        error => 'A really long error message to see if wrapping the text of this error looks good in the report that is generated for users to see why their build failed and what happened to cause it to fail.',
        start_time => UR::Time->now,
        end_time => UR::Time->now,
    );
}

######

package main;

Genome::Model::Command::Services::Build::Run::Test->runtests;

exit;

#$HeadURL$
#$Id$
