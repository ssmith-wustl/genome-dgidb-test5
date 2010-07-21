#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::Test;

# Since 'Base' is abstract, create a subclass to test
class Genome::Model::Build::Command::BaseTester { 
    is => 'Genome::Model::Build::Command::Base',
};
sub Genome::Model::Build::Command::BaseTester::execute {
    return $_[0]->_resolve_build;
}

###

package Genome::Model::Build::Command::Base::Test;

use base 'Genome::Utility::TestCommandBase';

sub test_class {
    return 'Genome::Model::Build::Command::BaseTester';
}

sub valid_param_sets {
    my $model = $_[0]->_model;
    return (
        {
            model_identifier => $model->id,
            method => 'last_succeeded',
        },
    );
}

sub invalid_param_sets {
    my $model = $_[0]->_model;
    return (
        {
            method => 'invalid',
        },
        {
            model_identifier => 'Not a model name',
        },
        {
            model_identifier => undef,
            build_id => undef,
        },
    );
}

sub _model {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_basic_mock_model(
            type_name => 'tester',
        );
        my $build = Genome::Model::Test->add_mock_build_to_model( $self->{_model} );
        #$build->event_status('Running
    }

    return $self->{_model};
}

sub startup : Tests(startup => no_plan) {
    my $self = shift;

    $self->_ur_no_commit_and_dummy_ids
        or die;
    
    return 1;
}

###

package main;

Genome::Model::Build::Command::Base::Test->runtests;

exit;

#$HeadURL$
#$Id$
