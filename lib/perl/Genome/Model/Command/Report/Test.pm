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

package Genome::Model::Command::Report::SummaryOfBuilds::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Test::More;

sub test_class {
    return 'Genome::Model::Command::Report::SummaryOfBuilds';
}

sub startup : Tests(startup => no_plan) {
    my $self = shift;

    #return 1; # uncomment this to see real data

    no warnings 'redefine';
    *Genome::Model::Command::Report::SummaryOfBuilds::_selectall_arrayref = sub{
        return $self->_rows;
    };

    return 1;
}

sub valid_param_sets {
    return (
        {
            after_execute => sub{
                my ($self, $generator, $param_set, $report) = @_;
                is($generator->were_builds_found, 5, 'Got all 5 builds for 2 models');
                #$self->_mail_report(@_); # uncommant to see it
                return 1;
            },
            work_order_id => 2196657, 
            #save => $_[0]->tmp_dir,
            #email => $ENV{USER}.'@genome.wustl.edu',
            #all_datasets => 1,
        },
        {
            after_execute => sub{ 
                my ($self, $generator, $param_set, $report) = @_;
                is($generator->were_builds_found, 2, 'Got only latest builds for 2 models.'); 
                #$self->_mail_report(@_); # uncommant to see it
                return 1;
            },
            work_order_id => 2196657, 
            most_recent_build_only => 1,
            #email => $ENV{USER}.'@genome.wustl.edu',
        },
        {
            processing_profile_id => 2067049, # WashU amplicon assembly
            most_recent_build_only => 1,
            #email => $ENV{USER}.'@genome.wustl.edu',
        },
        {
            type_name => 'amplicon assembly',
        },
        {
            subject_names => 'HMPZ-764083206-700024109,HMPZ-764083206-700037552',
            #email => $ENV{USER}.'@genome.wustl.edu',
        },
        {
            subject_names => 'HMPZ-764083206-700024109,HMPZ-764083206-700037552',
            #email => $ENV{USER}.'@genome.wustl.edu',
        },
    );
}

sub invalid_param_sets {
    return (
        {
            work_order_id => undef, 
        },
        {
            days => 'pp',
        },
    );
}

sub _required_params_for_class {
    return; 
}

sub _rows {
    return [
        [qw| 2816929868 98421143 Succeeded 2009-08-13 |],
        [qw| 2816929868 98421142 Succeeded 2009-08-27 |],
        [qw| 2816929867 98421141 Succeeded 2009-12-29 |],
        [qw| 2816929867 98421140 Succeeded 2009-08-28 |],
        [qw| 2816929867 98421139 Succeeded 2009-08-27 |],
    ];
}

#############################################################

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

