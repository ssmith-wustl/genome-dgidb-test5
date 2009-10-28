
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
        $self->{_model} = Genome::Model::Test->create_basic_mock_model(type_name => 'tester')
            or confess "Can't create mock tester model.";
    }

    return $self->{_model};
}

sub startup : Tests(startup => 1) {
    my $self = shift;
    
    no warnings 'once';
    *Genome::Model::Command::get_model_type_names = sub{ 
        return (qw/ tester /); 
    };
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

# 
sub __pre_execute {
    my $self = shift;

    print Dumper([$self->_model->inputs]);
    
    return 1;
}

sub __post_execute {
    my $self = shift;

    print Dumper([$self->_model->inputs]);
    
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
            values => 'Watson,Crick',
        },
        { # add single 'value'
            name => 'inst_data',
            values => '2sep09.934pmaa1',
        },
    );
}

sub invalid_param_sets {
    return (
        {# try to add a not 'is_many' input
            name => 'coolness', 
            values => 'none',
        },
        { # try to add Crick again
            name => 'friends',
            values => 'Crick',
        },
        { # try to add id that don't exist
            name => 'inst_data',
            values => '2sep09.934noexist',
        },
    );
}

sub _pre_execute {
    my ($self, $obj) = @_;

    my $name = $obj->name;
    my @values = $self->_model->$name;
    ok(!@values, "No $name found in model.");
    
    return 1;
}

sub _post_execute {
    my ($self, $obj) = @_;

    my $name = $obj->name;
    my @values = $self->_model->$name;
    ok(@values, "Added $name in model.");
    
    return 1;
}

###########################################################################

package Genome::Model::Command::Input::Remove::Test;

use strict;
use warnings;

use base 'Genome::Model::Command::Input::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Input::Remove';
}

sub _valid_param_sets {
    return (
        { # remove multiple 'value_ids' 
            name => 'friends',
            values => 'Watson,Crick',
        },
        { # remove single 'value'
            name => 'inst_data',
            values => '2sep09.934pmaa1',
        },
    );
}

sub invalid_param_sets {
    return (
        {# try to remove a not 'is_many' input
            name => 'coolness', 
            values => 'none',
        },
        { # try to remove input that is not linked to the model anymore
            name => 'inst_data',
            values => '2sep09.934pmaa1',
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

    return 1;
}

sub _post_execute {
    my ($self, $obj) = @_;

    my $name = $obj->name;
    my @values = $self->_model->$name;
    #print Dumper(\@values);
    ok(!@values, "Removed $name from model.");
    
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

