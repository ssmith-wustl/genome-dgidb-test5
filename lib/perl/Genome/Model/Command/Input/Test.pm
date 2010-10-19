
###########################################################################

package Genome::Model::Command::Input::Test;

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Input';
}



###########################################################################

package Genome::Model::Command::Input::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use Test::More;
require Genome::Model::Test;
require File::Temp;
require File::Path;

sub valid_param_sets {
    return grep { $_->{model_identifier} = $_[0]->_model->id } $_[0]->_valid_param_sets;
}

sub invalid_param_sets {
    return map { $_->{model_identifier} = $_[0]->_model->id } $_[0]->_valid_param_sets;
}

sub _model {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_mock_model(
            type_name => 'tester',
            instrument_data_count => 0,
        )
            or confess "Can't create mock tester model.";
    }

    return $self->{_model};
}

sub _build {
    my $self = shift;

    return ($self->_model->builds)[0];
}



sub startup : Tests(startup => no_plan) {
    my $self = shift;
    
    no warnings;
    *Genome::Model::Command::get_model_type_names = sub{ 
        return (qw/ tester /); 
    };
    use warnings;
    is_deeply(
        [ Genome::Model::Command->get_model_type_names ],
        [qw/ tester /],
        'Set tester type name.',
    );

    $self->_startup or confess "Failed startup.";
    
    return 1;
}

sub _startup {
    return 1;
}

###########################################################################

package Genome::Model::Command::Input::Add::Test;

use strict;
use warnings;

use base 'Genome::Model::Command::Input::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Input::Add';
}

sub _valid_param_sets {
    return (
        { # add multiple 'value_ids' 
            name => 'friends',
            ids => 'Watson,Crick',
            before_execute => '_before_execute',
            after_execute => '_after_execute',
        },
        { # add single 'value'
            name => 'inst_data',
            ids => '2sep09.934pmaa1',
            before_execute => '_before_execute',
            after_execute => '_after_execute',
        },
    );
}

sub invalid_param_sets {
    return (
        { # try to add a not 'is_many' input
            name => 'coolness', 
            ids => 'none',
        },
        { # try to add Crick again
            name => 'friends',
            ids => 'Crick',
        },
        { # try to add id that don't exist
            name => 'inst_data',
            ids => '2sep09.934noexist',
        },
    );
}

sub _before_execute {
    my ($self, $obj, $param_set) = @_;

    my $name = $obj->name;
    my @ids = $self->_model->$name;
    ok(!@ids, "No $name found for model.");
    
    return 1;
}

sub _after_execute {
    my ($self, $obj, $param_set) = @_;

    my $name = $obj->name;
    my @ids = $self->_model->$name;
    ok(@ids, "Added $name to model.");
    
    return 1;
}

###########################################################################

package Genome::Model::Command::Input::Remove::Test;

use strict;
use warnings;

use base 'Genome::Model::Command::Input::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use Genome::Utility::TestBase;
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Input::Remove';
}

sub _valid_param_sets {
    return (
        { # remove multiple 'value_ids' 
            name => 'friends',
            ids => 'Watson,Crick',
        },
        { # remove single 'value'
            name => 'inst_data',
            ids => '2sep09.934pmaa1',
            abandon_builds => 1,
        },
    );
}

sub invalid_param_sets {
    return (
        {# try to remove a not 'is_many' input
            name => 'coolness', 
            ids => 'none',
        },
        { # try to remove input that is not linked to the model anymore
            name => 'inst_data',
            ids => '2sep09.934pmaa1',
        },
    );
}

sub friends {
    return 'Crick';
}

sub inst_data {
    return Genome::InstrumentData::Sanger->get('2sep09.934pmaa1')
}

sub _startup {
    my $self = shift;

    my $model = $self->_model;

    $model->add_friend('Crick');
    $model->add_friend('Watson');
    my @friends = $model->friends();
    is_deeply(\@friends, [qw/ Crick Watson /], 'Added friends to remove.');
    my $id = Genome::InstrumentData::Sanger->get('2sep09.934pmaa1')
        or confess "Can't get sange id 2sep09.934pmaa1";
    $model->add_inst_data($id);
    my @inst_data = $model->inst_data;
    is_deeply(\@inst_data, [ $id ], 'Added instr_data to remove');
    
    my $build = $self->_build;
    my $build_input = Genome::Utility::TestBase->create_mock_object(
        class => 'Genome::Model::Build::Input',
        name => 'instrument_data',
        value_id => '2sep09.934pmaa1',
        build_id => $build->id,
    );
    $build->mock('abandon', sub{ return $build->build_event->event_status('Abandoned'); });

    return 1;
}

sub _post_execute {
    my ($self, $obj) = @_;

    my $name = $obj->name;
    my @ids = $self->_model->$name;
    #print Dumper(\@ids);
    ok(!@ids, "Removed $name from model.");
    if ( $obj->abandon_builds ) {
        is($self->_build->status, 'Abandoned', 'Successfully abandoned build');
    }

    return 1;
}

###########################################################################

package Genome::Model::Command::Input::List::Test;

use strict;
use warnings;

use base 'Genome::Model::Command::Input::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Input::List';
}

sub valid_param_sets {
    return (
        {
            filter => 'model_id='.$_[0]->_model->id,
        },
    );
}

sub invalid_param_sets {
}

sub _startup {
    my $self = shift;

    $self->_model->coolness('low');
    is($self->_model->coolness, 'low', 'Set coolness (input)');

    return 1;
}

###########################################################################

package Genome::Model::Command::Input::Names::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Input::Names';
}

sub valid_param_sets {
    return (
        {
            type_name => 'tester',
        },
    );
}

sub invalid_param_sets {
    return (
        {
            type_name => 'none',
        },
    );
}

sub startup : Tests(startup) {
    my $self = shift;
    
    no warnings 'once';
    no warnings 'redefine';
    *Genome::Model::Command::get_model_type_names = sub{ 
        return (qw/ tester /); 
    };
    
    return 1;
}

###########################################################################

package Genome::Model::Command::Input::Update::Test;

use strict;
use warnings;

use base 'Genome::Model::Command::Input::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Input::Update';
}

sub _valid_param_sets {
    return (
        { # remove single 'value'
            name => 'coolness',
            value => 'moderate',
        },
        { # remove single 'value'
            name => 'coolness',
            value => 'UNDEF',
        },
    );
}

sub invalid_param_sets {
    return (
        { # try to update an 'is_many' input
            name => 'friends',
            value => 'Watson',
        },
    );
}

###########################################################################

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2009 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

