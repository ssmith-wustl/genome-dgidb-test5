package Genome::Model::Command::Report::TestBase;

use strict;
use warnings;

use Carp 'confess';

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';
use Genome::Model::Test;
use Test::More;

sub _model {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_mock_model(
            type_name => 'amplicon assembly',
            use_mock_dir => 1
        )
            or die "Can't create mock model\n";
    }

    return $self->{_model};
}

sub _build_id {
    my $self = shift;

    return $self->_model->last_complete_build->build_id;
}


sub valid_param_sets {
    my $self = shift;
    my $build_id = $self->_build_id;
    return (
        map { $_->{build_id} = $build_id; $_ } $self->_valid_param_sets,
    );
}

sub _valid_param_sets {
    return ({});
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

sub _valid_param_sets {
    return (
        {
            report_name => 'Stats',
            directory => $_[0]->tmp_dir,
            force => 1,
        },
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

sub _valid_param_sets {
    return (
        {
            report_name => 'Stats',
            dataset_name => 'stats',
            output_type => 'csv',
            #output_type => 'xml',
        },
    );
}

########################################################

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

