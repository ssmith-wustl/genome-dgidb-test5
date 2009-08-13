###########################################################################

package Genome::Model::Command::Build::DeNovoAssembly::Test;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;
require File::Path;

use Data::Dumper 'Dumper';

sub import { # set ENVs
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

    return 1;
}

sub test_class {
    return 'Genome::Model::Command::Build::DeNovoAssembly';
}

sub _mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) {
        $self->{_mock_model} = Genome::Model::DeNovoAssembly::Test->create_mock_model
            or die "Can't create mock de novo assembly model\n";
    }

    return $self->{_mock_model};
}

sub _main_event {
    my ($self, $event) = @_;

    $self->{_main_event} = $event if $event;

    return $self->{_main_event};
}

sub test01_use : Test(4) {
    my $self = shift;

    use_ok('Genome::Model::DeNovoAssembly');
    use_ok('Genome::Model::DeNovoAssembly::Test');
    use_ok('Genome::ProcessingProfile::DeNovoAssembly');

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
    my $expected_event_count = 5;
    is(@events, $expected_event_count, "Scheduled $expected_event_count events");

    # The execution of these events are tested via the unit tests...but you may wanna make sure it works and see the results
    #  of the system running together
    if ( 1 ) {  
        for my $event ( @events ) {
	    diag($event->class);
            #ok($event->execute, sprintf('Executed event (%s %s)', $event->id, $event->event_type))
            #    or die; # if one of these fails just die
        }
        #print $build_event->build->data_directory,"\n##### HIT RETURN TO CONTINUE #####\n"; <STDIN>;
    }

    return 1;
}

###########################################################################

package Genome::Model::Command::Build::DeNovoAssembly::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

sub params_for_test_class {
    my $self = shift;
    my $model = $self->mock_model;
    return (
        model => $model,
        build => $model->latest_complete_build,
    );
}
sub required_params_for_class { return; }

sub mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) {
        $self->{_mock_model} = Genome::Model::DeNovoAssembly::Test->create_mock_model
            or die "Can't create mock de novo assembly model\n";
    }

    return $self->{_mock_model};
}

sub build {
    return $_[0]->mock_model->latest_complete_build;
}

sub _pre_execute { 1 }

sub test_01_execute : Test(2) {
    my $self = shift;

    #print Dumper({event_id=>$self->{_object}->id});
    ok($self->_pre_execute, 'Pre Execute')
        or die "Failed method _pre_execute\n";

    ok($self->{_object}->execute, "Execute");
    #print $self->build->data_directory,"\n"; <STDIN>;

    return 1;
}
### BASES ########################################################################

package Genome::Model::Command::Build::DeNovoAssembly::BaseTest;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;

sub test_01_use : Test(1) {
    my $self = shift;

    use_ok($self->test_class);

    return 1;
}
 
package Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentDataTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Build::DeNovoAssembly::BaseTest';

sub test_class {
    return 'Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData';
}

package Genome::Model::Command::Build::DeNovoAssembly::PreprocessTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Build::DeNovoAssembly::BaseTest';

sub test_class {
    return 'Genome::Model::Command::Build::DeNovoAssembly::Preprocess';
}

package Genome::Model::Command::Build::DeNovoAssembly::AssembleTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Build::DeNovoAssembly::BaseTest';

sub test_class {
    return 'Genome::Model::Command::Build::DeNovoAssembly::Assemble';
}

### VELVET ########################################################################

package Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentDataTest::VelvetTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Build::DeNovoAssembly::TestBase';

sub test_03_verify : Test(1) {
    my $self = shift;

    ok(-e $self->build->velvet_fastq_file, "Created velvet fastq file");

    return 1;
}

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData::Velvet';
}

package Genome::Model::Command::Build::DeNovoAssembly::Preprocess::VelvetTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Build::DeNovoAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Build::DeNovoAssembly::Preprocess::Velvet';
}


package Genome::Model::Command::Build::DeNovoAssembly::Assemble::VelvetTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Build::DeNovoAssembly::TestBase';

require File::Copy;
use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Command::Build::DeNovoAssembly::Assemble::Velvet';
}

sub _pre_execute {
    my $self = shift;

    File::Copy::copy("/gsc/var/cache/testsuite/data/Genome-Model-Tools-Velvet/Run/test.fastq", $self->build->velvet_fastq_file);

    *Genome::Model::Tools::Velvet::Run::execute = sub { 1 };

    return 1;
}

###########################################################################

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/Test.pm $
#$Id: Test.pm 45247 2009-03-31 18:33:23Z ebelter $

