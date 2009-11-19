#############################################################

package Genome::Model::Report::BuildReportsBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub test_class {
    return 'Genome::Model::Report::'.$_[0]->report_subclass;
}

sub _model {
    my $self = shift;
    
    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_mock_model(
            type_name => 'amplicon assembly',
            use_mock_dir => 1
        )
            or die "Can't get amplicon assembly mock model\n";
    }

    return $self->{_model};
}

sub _build_event {
    my $self = shift;

    return $self->_model->last_complete_build->build_event;
}

sub _build_id {
    my $self = shift;

    return $self->_model->last_complete_build->id;
}

sub params_for_test_class {
    return (
        build_id => $_[0]->_build_id,
        $_[0]->_additional_params_for_test_class,
    );
}

sub _additional_params_for_test_class {
    return;
}

sub _pre_generate {
    return 1;
}

sub _post_generate {
    return 1;
}

sub test01_generate_report : Tests() {
    my $self = shift;

    $self->_pre_generate or die "Can't run _pre_generate";
    
    my $generator = $self->{_object};
    my $report = $generator->generate_report;
    ok($report, 'Generated report');

    if ( 1 ) { # Email/save yourself the report if ya wanna
        #$report->save('/gscuser/ebelter', 1);
        my $email = Genome::Report::Email->send_report(
            report => $report,
            to => $ENV{USER}.'@genome.wustl.edu',
            xsl_files => [ $generator->get_xsl_file_for_html ],
            image_files => [ $generator->get_image_file_infos_for_html ],
        );
        print $report->xml_string."\n";
        #<STDIN>;
    }

    $self->_post_generate or die "Can't run _post_generate";

    return 1;
}

#############################################################

package Genome::Model::Report::BuildDailySummary::Test;

use strict;
use warnings;

use base 'Genome::Model::Report::BuildReportsBase';

use Test::More;

sub report_subclass {
    return 'BuildDailySummary';
}

sub params_for_test_class {
    return (
        #type_name => 'amplicon assembly',
        processing_profile_id => 2067049, # WashU amplicon assembly
        #show_most_recent_build_only => 1,
    );
}

sub _pre_generate {
    #return 1; # uncomment this to see real data
    my $self = shift;
    no warnings 'redefine';
    *Genome::Model::Report::BuildDailySummary::_selectall_arrayref = sub{
        return [ [qw|
        2816929867 H_MA-TestPatient1-MOBIOpwrsoil_3.WashU H_MA-TestPatient1-MOBIOpwrsoil_3 23
        98421139 /gscmnt/sata835/info/medseq/model_data/2816929867/build98421139 
        Succeeded 2009-08-27
        |] ]; 
    };
    return 1;
}

sub test02_create_failures : Tests() {
    my $self = shift;

    ok(!$self->test_class->create(), 'Failed as expected - create w/o id or type name');
    
    return 1;
}

#############################################################

package Genome::Model::Report::BuildInitialized::Test;

use strict;
use warnings;

use base 'Genome::Model::Report::BuildReportsBase';

use Test::More;

sub report_subclass {
    return 'BuildInitialized';
}

#############################################################

package Genome::Model::Report::BuildSucceeded::Test;

use strict;
use warnings;

use base 'Genome::Model::Report::BuildReportsBase';

use Test::More;

sub report_subclass {
    return 'BuildSucceeded';
}

#############################################################

package Genome::Model::Report::BuildFailed::Test;

use strict;
use warnings;

use base 'Genome::Model::Report::BuildReportsBase';

use Test::More;

sub report_subclass {
    return 'BuildFailed';
}

sub _additional_params_for_test_class {
    return (
        errors => $_[0]->_error_objects,
    );
}

sub _error_objects {
    my $self = shift;
    
    # Doing 2 errors to see in report
    my @errors;
    for (1..2) {
        my $error = $self->create_mock_object(
            class => 'Genome::Model::Build::Error',
            'build_event_id' => '97901036',
            'stage_event_id' => '97901036',
            'stage' => 'assemble',
            'step' => 'trim-and-screen',
            'step_event_id' => '97901040',
            'error' => 'A really long error message to see if wrapping the text of this error looks good in the report that is generated for users to see why their build failed and what happened to cause it to fail.',
        );
        $self->mock_methods($error, 'error_wrapped');
        $error->set_always('error_log', '/somewhere/a_log/file.err');
        push @errors, $error;
    }

    return \@errors;
}

#############################################################

1;

=pod

=head1 Tests

=head1 Disclaimer

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$

