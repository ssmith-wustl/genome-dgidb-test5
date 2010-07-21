#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

#<>#

package Genome::Model::Event::Build::Test;

use base 'Genome::Utility::TestCommandBase';

use Genome::Model::Test;

sub test_class {
    'Genome::Model::Event::Build';
}

sub required_property_names {
    return;
}

sub valid_param_sets {
    return (
        {
            model_id => $_[0]->_model_id,
        },
    );
}

sub _model_id {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_basic_mock_model(
            type_name => 'tester',
        );
    }

    return $self->{_model}->id;
}

sub startup : Tests(startup => no_plan) {
    my $self = shift;

    $self->_ur_no_commit_and_dummy_ids
        or die;
    
    return 1;
}

#<>#

package main;

Genome::Model::Event::Build::Test->runtests;

exit;


