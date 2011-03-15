
##########################################################

package Genome::Model::AmpliconAssembly::Report::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub generator {
    return $_[0]->{_object};
}

sub report_name {
    my $self = shift;

    my ($pkg) = $self->test_class =~ m/Genome::Model::AmpliconAssembly::Report::(\w+)$/;

    return 'Test '.$pkg.' Report',
}

sub params_for_test_class {
    return (
        build_id => $_[0]->mock_model->last_succeeded_build->id,
    );
}

sub mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) {
        $self->{_mock_model} = Genome::Model::Test->create_mock_model(
            type_name => 'amplicon assembly',
            use_mock_dir => 1,
        );
    }
    
    return $self->{_mock_model};
}

sub test_01_generate_report : Test(2) {
    my $self = shift;

    can_ok($self->generator, '_add_to_report_xml');

    my $report = $self->generator->generate_report;
    ok($report, 'Generated report');

    return 1;
}

######################################################################

package Genome::Model::AmpliconAssembly::Report::Stats::Test;

use strict;
use warnings;

use base 'Genome::Model::AmpliconAssembly::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::Model::AmpliconAssembly::Report::Stats';
}

######################################################################

package Genome::Model::AmpliconAssembly::Report::Composition::Test;

use strict;
use warnings;

use base 'Genome::Model::AmpliconAssembly::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::Model::AmpliconAssembly::Report::Composition';
}

######################################################################

package Genome::Model::AmpliconAssembly::Report::Summary::Test;

use strict;
use warnings;

use base 'Genome::Model::AmpliconAssembly::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::Model::AmpliconAssembly::Report::Summary';
}

######################################################################

1;

=pod

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
