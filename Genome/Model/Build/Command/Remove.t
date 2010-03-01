#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::Test;

###

package Genome::Model::Build::Command::Remove::Test;

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Build::Command::Remove';
}

sub valid_param_sets {
    return (
        {
            model_identifier => $_[0]->_model_id,
            method => 'last_succeeded',
        },
    );
}

sub __invalid_param_sets { # doesn't work - delete is not overwritten for some reason
    return (
        { # see what happens if delete returns false
            before_execute => '_overload_delete_to_return_false',
            after_execute => '_overload_delete_to_return_true',
        },
    );
}

sub _model_id {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_mock_model(
            type_name => 'tester',
        );
    }

    return $self->{_model}->id;
}

sub startup : Tests(startup => no_plan) {
    my $self = shift;

    # Overload delete and abandon to return true so that we are only testing this 
    #  command. Delete is NOT (FIXME) tested in Build.t
    #  and abandon is. Overloading these will allow the test to pass. They can then be
    #  overloaded to return false to test those failures.
    $self->_overload_delete_to_return_true;
    
    return 1;
}

# Overloads (not lords)
sub _overload_delete_to_return_false {
    no warnings;
    *Genome::Model::Build::delete = sub{ return; };
    return 1;
}

sub _overload_delete_to_return_true {
    no warnings;
    *Genome::Model::Build::delete = sub{ return 1; };
    return 1;
}

###

package main;

Genome::Model::Build::Command::Remove::Test->runtests;

exit;

#$HeadURL$
#$Id$
