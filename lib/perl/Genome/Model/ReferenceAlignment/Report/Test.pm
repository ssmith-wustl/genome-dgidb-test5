package Genome::Model::ReferenceAlignment::Report::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub generator {
    return $_[0]->{_object};
}

sub base_params_for_test_class {
    return (
        build_id => $_[0]->_mock_model->last_complete_build->id,
    );
}

sub required_params_for_class {
    return (qw/ build_id /);
}

sub _mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) { 
        $self->{_mock_model} = Genome::Model::Test->create_mock_model(
            type_name => 'reference alignment solexa',
        )
            or die;
    }

    return $self->{_mock_model};
}

sub skip_generate { return 0; }

#< Test Methods >#
sub test01_generate_report : Tests {
    my $self = shift;

    if ( $self->skip_generate ) {
        # Skipping generate...too many methods and data to mock.  This was not tested before
        can_ok($self->test_class, '_add_to_report_xml');
    }
    else {
        my $report = $self->generator->generate_report;
        ok($report, 'Generated report');
        #print Dumper($report);
    }
    
    # Save...maybe?  For comparison?
    # $report->name('Saved '.$report->name);
    # ok($self->report->save, 'Saved report');

    return 1;
}

#######################################################################

package Genome::Model::ReferenceAlignment::Report::DbSnpTest;

use strict;
use warnings;

use base 'Genome::Model::ReferenceAlignment::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::ReferenceAlignment::Report::DbSnp';
}

sub params_for_test_class {
    return (
        name => 'Db Snp',
        #override_model_snp_file => '/gsc/var/cache/testsuite/data/Genome-Model-ReferenceAlignment/build-50001/maq_snp_related_metrics/all.snps',
        $_[0]->base_params_for_test_class,
    );
}

#######################################################################

package Genome::Model::ReferenceAlignment::Report::GoldSnpTest;

use strict;
use warnings;

use base 'Genome::Model::ReferenceAlignment::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::ReferenceAlignment::Report::GoldSnp';
}

sub params_for_test_class {
    return (
        name => 'Gold Snp',
        $_[0]->base_params_for_test_class,
    );
}

sub skip_generate { return 1; }

#######################################################################

package Genome::Model::ReferenceAlignment::Report::SolexaStageOneTest;

use strict;
use warnings;

use base 'Genome::Model::ReferenceAlignment::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub generator {
    return $_[0]->{_object};
}

sub test_class {
    return 'Genome::Model::ReferenceAlignment::Report::SolexaStageOne';
}

sub params_for_test_class {
    return (
        $_[0]->base_params_for_test_class,
    );
}

sub skip_generate { return 1; }

#######################################################################

package Genome::Model::ReferenceAlignment::Report::SolexaStageTwoTest;

use strict;
use warnings;

use base 'Genome::Model::ReferenceAlignment::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::ReferenceAlignment::Report::SolexaStageTwo';
}

sub params_for_test_class {
    return (
        $_[0]->base_params_for_test_class,
    );
}

sub skip_generate { return 1; }

#######################################################################

package Genome::Model::ReferenceAlignment::Report::MapcheckTest;

use strict;
use warnings;

use base 'Genome::Model::ReferenceAlignment::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::ReferenceAlignment::Report::Mapcheck';
}

sub params_for_test_class {
    return (
        $_[0]->base_params_for_test_class,
    );
}

sub skip_generate { return 1; }

#######################################################################

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

