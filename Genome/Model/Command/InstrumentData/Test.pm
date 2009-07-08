
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

require Genome::Model::AmpliconAssembly::Test;
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

sub create_mock_model_and_instrument_data : Test(startup => 2) {
    my $self = shift;

    # model
    my $model = Genome::Model::AmpliconAssembly::Test->create_basic_mock_model;
    ok($model, 'Created mock model');
    $self->mock_methods(
        $model,
        'Genome::Model',
        (qw/
            assigned_instrument_data unassigned_instrument_data
            instrument_data_assignments 
            /),
    );

    $self->{_model} = $model;

    # instrument data
    my @instrument_data;
    for my $i (1..4) {
        my $run_name = '0'.$i.'jan00.101amaa';
        push @instrument_data, Genome::InstrumentData::Sanger->create_mock(
            id => $run_name,
            run_name => $run_name,
            sequencing_platform => 'sanger',
            seq_id => $run_name,
            sample_name => 'unknown',
            subset_name => 1,
            library_name => 'unknown',
        )
            or die "Can't create mock sanger instrument data";
    }

    is(scalar(@instrument_data), 4, 'Created 4 instrument data');
    $self->{_instrument_data} = \@instrument_data;

    $model->set_list('compatible_instrument_data', @instrument_data);
    
    return 1;
}

sub test_01_list : Tests {
    my $self = shift;

    ok($self->{_object}->execute, 'List instrument data');

    return 1;
}

sub test_02_assign_single_id : Tests {
    my $self = shift;

    my $assign = $self->_create_object(
        $self->params_for_test_class,
        instrument_data_id => $self->instrument_data->[0]->id,
    );
    ok($assign->execute, 'Assign single instrument data');

    return 1;
}

sub test_03_assign_multiple_id : Tests {
    my $self = shift;

    my $assign = $self->_create_object(
        $self->params_for_test_class,
        instrument_data_ids => join(
            ' ',
            $self->instrument_data->[1]->id,
            $self->instrument_data->[2]->id,
        ),
    );
    ok($assign->execute, 'Assign multiple instrument data');

    return 1;
}

sub test_04_assign_all : Tests {
    my $self = shift;

    my $assign = $self->_create_object(
        $self->params_for_test_class,
        all => 1,
    );
    ok($assign->execute, 'Assign all instrument data');

    return 1;
}

sub test_05_multiple_actions : Tests {
    my $self = shift;

    my $assign = $self->_create_object(
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
