package Genome::Model::Command::Build::ViromeScreen::Test;

use strict;
use warnings;

use base 'Test::Class';

require Genome::Model::Test;
use Test::More;
require File::Path;

use Data::Dumper 'Dumper';

sub import { # set ENVs
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

    return 1;
}

sub test_class {
    return 'Genome::Model::Command::Build::ViromeScreen';
}

sub _mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) {
        $self->{_mock_model} = Genome::Model::Test->create_mock_model(
            type_name => 'virome screen',
            instrument_data_count => 1,
        )
            or die "Can't create mock virome screen model\n";
    }

    return $self->{_mock_model};
}

sub _main_event {
    my ($self, $event) = @_;

    $self->{_main_event} = $event if $event;

    return $self->{_main_event};
}

sub test01_use : Test(3) {
    my $self = shift;

    use_ok('Genome::Model::ViromeScreen');
    use_ok('Genome::ProcessingProfile::ViromeScreen');
    ok($self->_mock_model, 'Got mock model');

    return 1;
}

sub test02_create : Test(5) {
    my $self = shift;

    my $model = $self->_mock_model;
    my $build_event = Genome::Model::Command::Build->create(
        model_id => $model->id,
        auto_execute => 0,
    );
    ok($build_event, 'Create build');
    isa_ok($build_event, 'Genome::Model::Command::Build');

    $build_event->queue_error_messages(1);
    $build_event->queue_warning_messages(1);

    ok($build_event->execute,'Execute build_event');

    is($build_event->warning_messages, undef, 'No warning messages for build_event');
    $build_event->dump_warning_messages(1);
    is($build_event->error_messages, undef, 'No error messages for build_event');
    $build_event->dump_error_messages(1);

    $self->_main_event($build_event);

    return 1;
}

sub test03_verify : Tests {
    my $self = shift;

    my $build_event = $self->_main_event;
    my $model = $self->_mock_model;
    my @events = sort { $b->genome_model_event_id <=> $a->genome_model_event_id } Genome::Model::Event->get(
        model_id => $model->id,
        build_id => $build_event->build_id,
        event_status => 'Scheduled',
    );
    my $expected_event_count = 4;
    is(@events, $expected_event_count, "Scheduled $expected_event_count events");

    # The execution of these events are tested via the unit tests..
    # but you may wanna make sure it works and see the results
    # of the system running together

    if ( 1 ) {  
        for my $event ( @events ) {
	    diag($event->class);
        }
    }

    return 1;
}

###########################################################################

package Genome::Model::Command::Build::ViromeScreen::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub params_for_test_class {
    my $self = shift;
    my $model = $self->mock_model;
    return (
        model => $model,
        build => $model->last_complete_build,
    );
}
sub required_params_for_class { return; }

sub mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) {
        $self->{_mock_model} = Genome::Model::Test->create_mock_model(type_name => 'virome screen')
            or die "Can't create mock virome screen model\n";
    }

    return $self->{_mock_model};
}

sub build {
    return $_[0]->mock_model->last_complete_build;
}

sub _pre_execute { 1 }

sub test_01_execute : Test(2) {
    my $self = shift;

    ok($self->_pre_execute, 'Pre Execute')
        or die "Failed method _pre_execute\n";

    ok($self->{_object}->execute, "Execute");

    return 1;
}

###########################################################################

package Genome::Model::Command::Build::ViromeScreen::PrepareInstrumentDataTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Build::ViromeScreen::TestBase';

sub test_class {
    return 'Genome::Model::Command::Build::ViromeScreen::PrepareInstrumentData';
}

###########################################################################

package Genome::Model::Command::Build::ViromeScreen::ScreenTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Build::ViromeScreen::TestBase';

sub test_class {
    return 'Genome::Model::Command::Build::ViromeScreen::Screen';
}

1;
