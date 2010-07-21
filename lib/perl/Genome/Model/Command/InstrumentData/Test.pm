# FIXME ebelter
#  Long: Remove or update to use inputs as appropriate.

########################################################################

package Genome::Model::Command::InstrumentData::Test;

use strict;
use warnings;

#use base 'Genome::Utility::TestBase';


########################################################################

package Genome::Model::Command::InstrumentData::Assign::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

require Genome::Model::Test;
use Test::More;

sub test_class {
    return 'Genome::Model::Command::InstrumentData::Assign';
}

sub params_for_test_class {
    return (
        model_id => $_[0]->model_id,
    );
}

sub required_params_for_class {
    return (qw/ model_id /);
}

sub model { return $_[0]->{_model}; }
sub model_id { return $_[0]->{_model}->id; }
sub instrument_data { return $_[0]->{_instrument_data}; }
sub solexa_instrument_data { return $_[0]->{_solexa_instrument_data};}

sub create_mock_model_and_instrument_data : Test(startup => 2) {
    my $self = shift;

    # model
    my $model = Genome::Model::Test->create_basic_mock_model(type_name => 'tester');
    ok($model, 'Created mock model') or die;
    $self->{_model} = $model;

    # instrument data
    my @instrument_data = Genome::Model::Test->create_mock_sanger_instrument_data(4);
    is(scalar(@instrument_data), 4, 'Created 4 instrument data');
    $self->{_instrument_data} = \@instrument_data;

    # solexa instrument data, needed for testing assignment by flowcell-id, which only works with solexa data ATM
    my @solexa_instrument_data = Genome::Model::Test->create_mock_solexa_instrument_data(8);
    is(scalar(@solexa_instrument_data), 8, 'Created 8 solexa instrument data');
    $self->{_solexa_instrument_data} = \@solexa_instrument_data;

    $model->set_list('compatible_instrument_data', @instrument_data,@solexa_instrument_data);
    
    return 1;
}

sub test_01_list : Tests {
    my $self = shift;

    ok($self->{_object}->execute, 'List instrument data');

    return 1;
}

sub test_02_assign_single_id : Tests {
    my $self = shift;

    my $assign = $self->test_class->create(
        $self->params_for_test_class,
        instrument_data_id => $self->instrument_data->[0]->id,
        force => 1,
    );
    ok($assign->execute, 'Assign single instrument data');

    return 1;
}

sub test_03_assign_multiple_id : Tests {
    my $self = shift;

    my $assign = $self->test_class->create(
        $self->params_for_test_class,
        instrument_data_ids => join(
            ' ',
            $self->instrument_data->[1]->id,
            $self->instrument_data->[2]->id,
        ),
        force => 1,
    );
    ok($assign->execute, 'Assign multiple instrument data');

    return 1;
}

sub test_04_assign_flow_cell_id : Tests {
    my $self = shift;

    my $old_subject_name = $self->model->subject_name;
    #unfortunately, the look up requires the model to have the same name as the sample_name column in solexa_run_lane
    #we'll change it back to *.mock when finished
    $self->model->subject_name('H_GV-933124G-S.9017');
    my $assign = $self->test_class->create(
        $self->params_for_test_class,
        flow_cell_id => $self->solexa_instrument_data->[0]->flow_cell_id,
        force => 1,
    );
    ok($assign->execute, 'Assign multiple instrument data by flow_cell_id');
    $self->model->subject_name($old_subject_name);
    
    return 1;
}

sub test_05_assign_all : Tests {
    my $self = shift;

    my $assign = $self->test_class->create(
        $self->params_for_test_class,
        all => 1,
    );
    ok($assign->execute, 'Assign all instrument data');

    return 1;
}



sub test_06_multiple_actions : Tests {
    my $self = shift;

    my $assign = $self->test_class->create(
        all => 1,
        instrument_data_ids => '44 44',
    );
    ok(!$assign, 'Failed as expected - request multiple actions');

    return 1;
}



########################################################################

1;

#$HeadURL$
#$Id$
