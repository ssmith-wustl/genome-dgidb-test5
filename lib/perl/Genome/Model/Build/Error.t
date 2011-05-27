#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

######

package Genome::Model::Build::Error::Test;

use base 'Genome::Utility::TestBase';

use Data::Dumper;
use Test::More;

sub test_class {
    return 'Genome::Model::Build::Error';
}

sub params_for_test_class {
    return (
        build_event_id => 1,#$self->{_build_event_id},
        stage_event_id => 1,#$self->{_build_event_id},
        stage => 'assemble',
        step_event_id => $_[0]->{_step_event_id},
        step => 'trim-and-screen',
        error => 'This totally died.',
    );
}

sub startup : Tests(startup => 1) {
    my $self = shift;

    my $step_event = $self->create_mock_object(
        class => 'Genome::Model::Event',
    );
    $step_event->set_always('error_log_file', 'log_dir/error.err');
    ok($step_event, 'Created step event');
    $self->{_step_event_id} = $step_event->id;

    return 1;
}

sub test01_derived_properties : Tests(2) {
    my $self = shift;

    is($self->{_object}->error_log, 'log_dir/error.err', 'Log file');
    ok($self->{_object}->error_wrapped, 'Wrapped error');

    return 1;
}

sub test02_create_from_workflow_error : Tests(2) {
    my $self = shift;

    my @wf_errors = $self->_create_wf_errors;
    is(scalar(@wf_errors), 2, 'Created 2 wf errors');
    my @errors = $self->test_class->create_from_workflow_errors(@wf_errors);
    is(scalar(@errors), 1, 'Converted 1 wf errors to build errors');

    return 1;
}

sub _create_wf_errors  {
    my $self = shift;

    my @wf_errors;
    push @wf_errors, $self->create_mock_object(
        class => 'Workflow::Operation::InstanceExecution::Error',
        # BUILD_EVEVNT_ID STAGE
        name => '97901036 assemble',
        # BUILD_EVEVNT_ID STAGE
        path_name => '97901036 all stages',
        _build_path_string => '97901036 all stages',
        # LSF_JOB_ID maybe undef
        dispatch_identifier => undef,
        # ERROR_STRING
        error => <<EOS,
Execution halted due to unresolvable dependencies or crashed children.  Status and incomplete inputs:
input connector <591875> (done)
output connector <591876> (new)
  result
verify-instrument-data 97901037 <591877> (done)
prepare-instrument-data 97901038 <591878> (done)
trim-and-screen 97901039 <591879> (crashed)
assemble 97901040 <591880> (new)
  prior_result
classify 97901041 <591881> (new)
  prior_result
orient 97901042 <591882> (new)
  prior_result
collate 97901043 <591883> (new)
  prior_result
clean-up 97901044 <591884> (new)
  prior_result
reports 97901045 <591885> (new)
  prior_result
merge results <591886> (new)
  result_1
EOS
        ,
        start_time => UR::Time->now,
        end_time => UR::Time->now,
    );

    push @wf_errors, $self->create_mock_object(
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

    return @wf_errors;
}

######

package main;

Genome::Model::Build::Error::Test->runtests;

exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

