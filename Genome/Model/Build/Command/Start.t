#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::Test;

###

package Genome::Model::Build::Command::Start::Test;

use base 'Genome::Utility::TestCommandBase';

sub test_class {
    return 'Genome::Model::Build::Command::Start';
}

sub valid_param_sets {
    return (
        {
            before_execute => '_overload_execute_bsub_command',
            model_identifier => $_[0]->_model_id,
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

sub _overload_execute_bsub_command {
    no warnings;
    *Genome::Model::Build::Command::Start::_execute_bsub_command = sub{ return 1; };
    return 1;
}

###

package main;

Genome::Model::Build::Command::Start::Test->runtests;

exit;

#$HeadURL$
#$Id$
