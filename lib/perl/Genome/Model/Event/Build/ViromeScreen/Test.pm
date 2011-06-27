###########################################################################

package Genome::Model::Event::Build::ViromeScreen::TestBase;

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

    $DB::single = 1;
    ok($self->{_object}->execute, "Execute");

    return 1;
}

###########################################################################

package Genome::Model::Event::Build::ViromeScreen::PrepareInstrumentDataTest;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::ViromeScreen::TestBase';

sub test_class {
    return 'Genome::Model::Event::Build::ViromeScreen::PrepareInstrumentData';
}

###########################################################################

package Genome::Model::Event::Build::ViromeScreen::ScreenTest;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::ViromeScreen::TestBase';

#sub test_01_verify : Test(2) {
#    my $self = shift;
#    ok (-s $self->build->barcode_file, "Barcode file exists");
#    ok ($self->build->log_file, "Can specify og file name");
#}

sub test_class {
    return 'Genome::Model::Event::Build::ViromeScreen::Screen';
}

1;
