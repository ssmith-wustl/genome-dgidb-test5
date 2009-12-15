###########################################################################

package Genome::Model::Event::Build::DeNovoAssembly::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

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
        $self->{_mock_model} = Genome::Model::Test->create_mock_model(type_name => 'de novo assembly')
            or die "Can't create mock de novo assembly model\n";
    }

    return $self->{_mock_model};
}

sub build {
    return $_[0]->mock_model->last_complete_build;
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

package Genome::Model::Event::Build::DeNovoAssembly::BaseTest;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;

sub test_01_use : Test(1) {
    my $self = shift;

    print $self->test_class."\n";

    use_ok($self->test_class);

    return 1;
}
 
package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentDataTest;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::DeNovoAssembly::BaseTest';

sub test_class {
    return 'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData';
}

package Genome::Model::Event::Build::DeNovoAssembly::PreprocessTest;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::DeNovoAssembly::BaseTest';

sub test_class {
    return 'Genome::Model::Event::Build::DeNovoAssembly::Preprocess';
}

package Genome::Model::Event::Build::DeNovoAssembly::AssembleTest;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::DeNovoAssembly::BaseTest';

sub test_class {
    return 'Genome::Model::Event::Build::DeNovoAssembly::Assemble';
}

### VELVET ########################################################################

package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentDataTest::VelvetTest;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::DeNovoAssembly::TestBase';

sub test_03_verify : Test(1) {
    my $self = shift;

    ok(-e $self->build->velvet_fastq_file, "Created velvet fastq file");

    return 1;
}

use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet';
}

package Genome::Model::Event::Build::DeNovoAssembly::Preprocess::VelvetTest;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::DeNovoAssembly::TestBase';

use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::DeNovoAssembly::Preprocess::Velvet';
}


package Genome::Model::Event::Build::DeNovoAssembly::Assemble::VelvetTest;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::DeNovoAssembly::TestBase';

require File::Copy;
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::DeNovoAssembly::Assemble::Velvet';
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

