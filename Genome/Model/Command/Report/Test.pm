package Genome::Model::Command::Report::TestBase;

use strict;
use warnings;

use Carp 'confess';
$SIG{__DIE__} = sub{ confess(@_) };

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Genome;
use Genome::Model::AmpliconAssembly::Test;
use Test::More;

sub _model {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::AmpliconAssembly::Test->create_mock_model(use_test_dir => 1)
            or die "Can't create mock model\n";
    }

    return $self->{_model};
}

sub _build {
    my $self = shift;

    return $self->_model->latest_complete_build;
}

sub params_for_test_class {
    return (
        build_id => $_[0]->_build->build_id,
        $_[0]->_params_for_test_class,
    );
}

sub _params_for_test_class {
    return;
}

sub test_01_execute : Tests {
    my $self = shift;

    ok($self->{_object}->execute, 'Execute');
    
    return 1;
}

########################################################

package Genome::Model::Command::Report::GenerateTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Report::TestBase';

use Data::Dumper 'Dumper';

sub test_class {
    return 'Genome::Model::Command::Report::Generate';
}

sub _params_for_test_class {
    return (
        report_name => 'Assembly Stats',
        directory => '/gscuser/ebelter/Desktop',
        force => 1,
    );
}

########################################################

package Genome::Model::Command::Report::GetDatasetTest;

use strict;
use warnings;

use base 'Genome::Model::Command::Report::TestBase';

use Data::Dumper 'Dumper';

sub test_class {
    return 'Genome::Model::Command::Report::GetDataset';
}

sub _params_for_test_class {
    return (
        report_name => 'Assembly Stats',
        dataset_name => 'stats',
        output_type => 'csv',
        #output_type => 'xml',
    );
}

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

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$

