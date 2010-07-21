###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub params_for_test_class {
    return (
        model => $_[0]->_mock_model,
        build => $_[0]->_mock_build,
    );
}
sub required_params_for_class { return; }

sub _mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) {
        $self->{_mock_model} = Genome::Model::Test->create_mock_model(
            type_name => 'amplicon assembly',
        )
            or confess "Can't create mock amplicon assembly model";
    }

    return $self->{_mock_model};
}

sub _mock_build {
    return $_[0]->_mock_model->last_succeeded_build || die "No succeeded mock build";
}

sub _amplicons {
    return $_[0]->_mock_build->get_amplicons;
}

# Setup
sub should_copy_traces { 0 }
sub should_copy_edit_dir { 0 }
sub _pre_execute { 1 }

sub test_01_execute : Tests {
    my $self = shift;

    # aa
    my $amplicon_assembly = Genome::AmpliconAssembly->create(
        directory => $self->_mock_build->data_directory,
    );
    ok($amplicon_assembly, 'Created amplicon assembly');
    
    # traces
    if ( $self->should_copy_traces ) {
        ok( 
            Genome::Model::Test->copy_test_dir(
                $self->base_test_dir.'/Genome-Model-AmpliconAssembly/build-10000/chromat_dir',
                $self->_mock_build->chromat_dir,
            ),
            "Copy traces"
        ) or die;
    }

    # edit_dir
    if ( $self->should_copy_edit_dir ) {
        ok(
            Genome::Model::Test->copy_test_dir(
                $self->base_test_dir.'/Genome-Model-AmpliconAssembly/build-10000/edit_dir',
                $self->_mock_build->edit_dir,
            ),
            "Copy edit_dir"
        ) or die;
    }

    # Overwrite the execute method in the tool, so we don't redunduntly test (if applicable)
    my $class = $self->test_class;
    $class =~ s/Event::Build/Tools/; # get teh tool class
    my $execute; # to save the original execute
    eval "use $class"; # use to see if exists
    no strict 'refs'; # w/ these on, reassigning execute causes errors
    no warnings;
    unless ( $@ ) { # the tool exists, overwrite the execute to a null sub
        $execute = \&{$class.'::execute'};
        *{$class.'::execute'} = sub{ return 1; };
    }

    #ok($self->_pre_execute, 'Pre Execute') or die "Failed method _pre_execute\n";
$DB::single=1;
    ok($self->{_object}->execute, "Execute") or die "Failed execute\n";

    *{$class.'::execute'} = $execute if $execute;

    #print Dumper({event_id=>$self->{_object}->id});
    #print $self->_mock_build->data_directory,"\n"; <STDIN>;

    return 1;
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::Assemble::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::Assemble';
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::Classify::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::Classify';
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::CleanUp::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::CleanUp';
}

sub should_copy_traces { 1 }
sub should_copy_edit_dir { 1 }

sub test_03_verify : Test(1) {
    my $self = shift;

    my @files_remaining = glob($self->_mock_build->edit_dir.'/*');
    is(@files_remaining, 50, "Removed correct number of files");

    return 1;
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::Collate::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::Collate';
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::ContaminationScreen::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::ContaminationScreen';
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::PrepareInstrumentData::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::PrepareInstrumentData';
}

sub should_copy_traces { 1 }

sub test_03_verify : Test(1) {
    my $self = shift;

    my $fasta_cnt = grep { -s $_->fasta_file } @{$self->_amplicons};
    ok($fasta_cnt, 'Prepared instrument data');
    
    return 1;
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::Orient::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::Orient';
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::Reports::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::Reports';
}

sub should_copy_traces { 1 }
sub should_copy_edit_dir { 1 }

sub test_03_verify : Test(1) {
    my $self = shift;

    #diag($self->_mock_build->resolve_reports_directory); <STDIN>;
    my @reports = glob($self->_mock_build->resolve_reports_directory.'/*');
    is(@reports, 2, "Created 2 reports");

    return 1;
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::TrimAndScreen::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::TrimAndScreen';
}

sub should_copy_traces { 1 }
sub should_copy_edit_dir { 1 }

sub test_03_verify {#: Test(1) {
    my $self = shift;

    my @reports = glob($self->_mock_build->resolve_reports_directory.'/*');
    is(@reports, 2, "Created 2 reports");

    return 1;
}

###########################################################################

package Genome::Model::Event::Build::AmpliconAssembly::VerifyInstrumentData::Test;

use strict;
use warnings;

use base 'Genome::Model::Event::Build::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Event::Build::AmpliconAssembly::VerifyInstrumentData';
}

sub test_03_verify : Test(1) {
    my $self = shift;

    my $amplicons = $self->_amplicons;
    ok(@$amplicons, 'Verified linking of instrument data');
    
    return 1;
}

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

#$HeadURL$
#$Id$

