#############################################################

package Genome::Model::Report::BuildEventReportsBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

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

sub test01_generate_report : Tests() {
    my $self = shift;

    my $report = $self->{_object}->generate_report;
    ok($report, 'Generated report');

    if ( 0 ) { # Email/save yourself the report if ya wanna
        #$report->save('/gscuser/ebelter', 1);
        my $email = Genome::Report::Email->send_report(
            report => $report,
            to => $ENV{USER}.'@genome.wustl.edu',
            xsl_files => [ $report->generator->get_xsl_file_for_html ],
            image_files => [ $report->generator->get_image_file_infos_for_html ],
        );
        print $report->xml_string."\n";
        #<STDIN>;
    }

    return 1;
}

#############################################################

package Genome::Model::Report::BuildInitialized::Test;

use strict;
use warnings;

use base 'Genome::Model::Report::BuildEventReportsBase';

use Test::More;

sub report_subclass {
    return 'BuildInitialized';
}

#############################################################

package Genome::Model::Report::BuildSucceeded::Test;

use strict;
use warnings;

use base 'Genome::Model::Report::BuildEventReportsBase';

use Test::More;

sub report_subclass {
    return 'BuildSucceeded';
}

#############################################################

package Genome::Model::Report::BuildFailed::Test;

use strict;
use warnings;

use base 'Genome::Model::Report::BuildEventReportsBase';

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
    
    my $error1 = Test::MockObject->new();
    $error1->set_isa('Workflow::Operation::InstanceExecution::Error');
    $self->_set_mock_attrs( 
        $error1, {
            # BUILD_EVEVNT_ID STAGE
            name => '97901036 assemble',
            # BUILD_EVEVNT_ID STAGE
            path_name => '97901036 all stages',
            _build_path_string => '97901036 all stages',
            # LSF_JOB_ID maybe undef
            dispatch_identifier => undef,
            # ERROR_STRING
            error => <<EOS,
Execution halted due to unresolvable dependencies or crashed children.  Status and incomplete inputs:
input connector <591875> (done)
output connector <591876> (new)
  result
verify-instrument-data 97901037 <591877> (done)
prepare-instrument-data 97901038 <591878> (done)
trim-and-screen 97901039 <591879> (crashed)
assemble 97901040 <591880> (new)
  prior_result
classify 97901041 <591881> (new)
  prior_result
orient 97901042 <591882> (new)
  prior_result
collate 97901043 <591883> (new)
  prior_result
clean-up 97901044 <591884> (new)
  prior_result
reports 97901045 <591885> (new)
  prior_result
merge results <591886> (new)
  result_1
EOS
            ,
            start_time => UR::Time->now,
            end_time => UR::Time->now,
        },
    );

    my $error2 = Test::MockObject->new();
    #$error2->set_isa('Workflow::Operation::InstanceExecution::Error');
    $self->_set_mock_attrs( 
        $error2, {
            # STEP EVENT_ID  
            name => 'trim-and-screen 97901039',
            # BUILD_EVEVNT_ID STAGE/STEP EVENT_ID  
            path_name => '97901036 all stages/97901036 assemble',
            _build_path_string=> '97901036 all stages/97901036 assemble',
            # LSF_JOB_ID maybe undef
            dispatch_identifier => 1000001,
            # ERROR_STRING
            error => 'Command module returned undef',
            start_time => UR::Time->now,
            end_time => UR::Time->now,
        },
    );

    my $error3 = Test::MockObject->new();
    #$error3->set_isa('Workflow::Operation::InstanceExecution::Error');
    $self->_set_mock_attrs( 
        $error3, {
            # STEP EVENT_ID  
            name => 'trim-and-screen 97901040',
            # BUILD_EVEVNT_ID STAGE/STEP EVENT_ID  
            path_name => '97901036 all stages/97901036 assemble/trim-and-screen 97901040',
            _build_path_string=> '97901036 all stages/97901036 assemble/trim-and-screen 97901040',
            # LSF_JOB_ID maybe undef
            dispatch_identifier => 1000002,
            # ERROR_STRING
            error => 'A really long error message to see if wrapping the text of this error looks good in the report that is generated for users to see why their build failed and what happened to cause it to fail.',
            start_time => UR::Time->now,
            end_time => UR::Time->now,
        },
    );

    my $error4 = Test::MockObject->new();
    #$error4->set_isa('Workflow::Operation::InstanceExecution::Error');
    $self->_set_mock_attrs( 
        $error4, {
            # STEP EVENT_ID  
            name => 'trim-and-screen 97901041',
            # BUILD_EVEVNT_ID STAGE/STEP EVENT_ID  
            path_name => '97901036 all stages/97901036 assemble/trim-and-screen 97901041',
            _build_path_string=> '97901036 all stages/97901036 assemble/trim-and-screen 97901041',
            # LSF_JOB_ID maybe undef
            dispatch_identifier => 1000003,
            # ERROR_STRING
            error => 'Can\'t call method "run" on undefined value',
            start_time => UR::Time->now,
            end_time => UR::Time->now,
        },
    );

    return [ $error1, $error2, $error3, $error4 ];
}

sub _set_mock_attrs {
    my ($self, $obj, $params) = @_;

    for my $attr ( keys %$params ) {
        #$obj->set_always($attr, $params->{$attr});
        $obj->mock($attr, sub { return $params->{$attr}; });
    }

    return 1;
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

