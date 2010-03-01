#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::Test;

###

package Genome::Model::Build::Command::Abandon::Test;

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Build::Command::Abandon';
}

sub valid_param_sets {
    return (
        {
            model_identifier => $_[0]->_model_id,
            method => 'last_succeeded',
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

    # overload G:M:Build abandon - this is covered in G:M:Build.t
    no warnings;
    *Genome::Model::Build::abandon = sub{ return 1; };
    
    return 1;
}

###

package main;

Genome::Model::Build::Command::Abandon::Test->runtests;

exit;

#$HeadURL$
#$Id$
