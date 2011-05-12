package Genome::Report::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;
use XML::LibXML;

sub report {
    return $_[0]->{_object};
}

sub reports_dir {
    return $_[0]->dir.'/xml_reports';
}

sub test_class {
    'Genome::Report';
}

sub params_for_test_class {
    my $xml = XML::LibXML->new->parse_string( _xml_string() )
        or die "Can't parse xml string\n";
    return (
        xml => $xml,
    );
}

sub _xml_string {
        return <<EOS
<?xml version="1.0"?>
<report>
  <datasets>
    <stats>
      <stat>
        <assembled>4</assembled>
        <attempted>5</attempted>
      </stat>
    </stats>
  </datasets>
   <report-meta>
    <name>Assembly Stats</name>
    <description>Assembly Stats for Amplicon Assembly (Name &lt;mr. mock&gt; Build Id &lt;-10000&gt;)</description>
    <date>2009-05-29 10:19:10</date>
    <generator>Genome::Model::AmpliconAssembly::Report::AssemblyStats</generator>
    <generator-params>
      <build-id>-10000</build-id>
      <amplicons>HMPB-aad16a01</amplicons>
      <amplicons>HMPB-aad16c10</amplicons>
    </generator-params>
  </report-meta>
</report>
EOS
}

sub _report_meta_hash {
    return (
        name => 'Assembly Stats',
        description => 'Assembly Stats for Amplicon Assembly (Name <mr. mock> Build Id <-10000>)',
        date => '2009-05-29 10:19:10',
        generator => 'Genome::Model::AmpliconAssembly::Report::AssemblyStats',
        generator_params => {
            build_id => [ -10000 ],
            amplicons => [qw/ HMPB-aad16a01 HMPB-aad16c10 /],
        },
    );
}

sub get_report_for_testing {
    return $_[0]->create_valid_object;
}

sub test00_attrs : Test(8) {
    my $self = shift;

    my $report = $self->report;

    # meta
    my %report_meta = $self->_report_meta_hash;
    for my $attr ( keys %report_meta ) {
        is_deeply($report->$attr, $report_meta{$attr}, $attr);
    }
    
    # dir
    ok(!$report->parent_directory, 'parent directory is undef');
    ok(!$report->directory, "Can't access directory w/o setting parent directory");
    
    # datasets
    my @datasets = $report->get_dataset_nodes;
    ok(@datasets, 'datasets') or die;
    my ($stats) = $report->get_dataset_nodes_for_name('stats');
    ok($stats, 'Dataset node: stats') or die;
    is($datasets[0]->nodeName, $stats->nodeName, 'Dataset name: stats');

    return 1;
}

sub test01_save_report : Test(6) {
    my $self = shift;

    # Save - fails
    ok(!$self->report->save, 'Failed as expected - no directory');
    ok(!$self->report->save('invalid_directory'), 'Failed as expected - invalid directory');

    # Save
    ok($self->report->save( $self->tmp_dir ), 'Saved report to tmp dir');
    is($self->report->directory, $self->tmp_dir.'/Assembly_Stats', 'Directory name matches');
    
    # Resave 
    ok(!$self->report->save( $self->tmp_dir ), 'Failed as expected - resave report');
    ok($self->report->save($self->tmp_dir, 1), 'Overwrite report');

    return 1;
}

sub test02_create_report_from_directories : Tests {
    my $self = shift;
    
    # Get it w/ parent dir
    my @reports = $self->test_class->create_reports_from_parent_directory( $self->reports_dir );
    is(@reports, 2, 'Got two reports using create_reports_from_parent_directory');
    is($reports[0]->name, 'Test Report 1', 'Report 1 has correct name');
    is($reports[0]->parent_directory, $self->reports_dir, 'Report 1 has correct parent directory');
    #is($reports[0]->directory, $self->reports_dir.'/Test_Report_1', 'Report 1 has correct directory');
    is($reports[1]->name, 'Test Report 2', 'Report 2 has correct name');
    is_deeply(
        $reports[1]->generator_params,
        { 'scalar' => [qw/ yes /], array => [qw/ 1 2 /] },
        'Test Report 1 - gen params'
    );

    return 1;
}

sub test03_other_get_and_create_fails : Tests {
    my $self = shift;

    my $valid_name = 'Test Report';
    my $valid_dir = $self->dir;
    my @reports;

    # get - can't
    eval {
        @reports = $self->test_class->get(xml => _xml_string());
    };
    print "$@\n";
    ok(!@reports, 'Failed as expected - get');

    # create w/ invalid parent dir
    eval {
        @reports = $self->test_class->create_reports_from_parent_directory('no_way_this_dir_exists');
    };
    print "$@\n";
    ok(!@reports, 'Failed as expected - create reports w/ invalid parent_directory');

    return 1;
}

#######################################################################

package Genome::Report::Generator::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Report::Generator';
}

sub method_for_execution {
    return 'generate_report';
}

sub valid_param_sets {
    return (
        { # name test
            before_execute => 'test_report_attributes',
        },
    );
}

sub startup : Tests(startup) {
    my $self = shift;

    no warnings;
    *Genome::Report::Generator::_add_to_report_xml = sub{ return 1; };
    *Genome::Report::Generator::description = sub{ return 'Test report generator'; };
    
    return 1;
}

sub test_report_attributes {
    my ($self, $generator) = @_;
    
    is($generator->name, 'Generator', 'name');
    is($generator->generator, 'Genome::Report::Generator', 'generator');
    ok($generator->date, 'date');
    
    return 1;
}

#######################################################################

package Genome::Report::GeneratorCommand::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Report::GeneratorCommand';
}

sub params_for_test_class {
    return (
        print_xml => 1,
        #print_datasets => 1,
        #datasets => 'rows',
        #email => Genome::Config->user_email,
    );
}

sub test01_generate_report_and_execute_functions : Tests(2) {
    my $self = shift;

    my $report = $self->{_object}->_generate_report_and_execute_functions(
        name => 'Rows n Stuff',
        description => 'Testing the generator command',
        headers => [qw/ column1 column2 colum3 /],
        rows => [ [qw/ row1.1 row1.2 row1.3 /], [qw/ row2.1 row2.2 row2.3 /] ],
    );
    ok($report, 'Generated report');
    isa_ok($report, 'Genome::Report');

    return 1;
}

#######################################################################

package Genome::Report::Dataset::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class { 
    return 'Genome::Report::Dataset';
}

sub params_for_test_class {
    return (
        name => 'stats',
        row_name => 'stat',
        headers => [qw/ attempted assembled assembled-percent /],
        rows => [ [qw/ 4 5 80.0% /] ],
        attributes => { good => 'mizzou', bad => 0 },
    );
}

sub test01_xml : Tests(2) {
    my $self = shift;

    my $dataset = $self->{_object};
    ok($dataset->to_xml_element, 'XML element');
    ok($dataset->to_xml_string, 'XML string');
    
    return 1;
}

sub test02_svs : Tests(1) {
    my $self = shift;

    is(
        $self->{_object}->to_separated_value_string(separator => '|'), 
        "attempted|assembled|assembled-percent\n4|5|80.0\%\n",
        'SVS string',
    );
    is(
        $self->{_object}->to_separated_value_string(separator => '|', include_headers => 0), 
        "4|5|80.0\%\n",
        'SVS string',
    );

    return 1;
}

sub test03_attributes : Tests(2) {
    my $self = shift;

    is(
        $self->{_object}->get_attribute('good'), 
        'mizzou',
        'get_attribute good => mizzou',
    );
    ok(
        $self->{_object}->set_attribute('bad', 'kansas'), 
        'set_attribute bad => kansas',
    );

    return;
}

sub test04_create_from_xml_element : Tests(6) {
    my $self = shift;

    my $ds = $self->{_object};
    my $from_element_ds = $self->test_class->create_from_xml_element($self->{_object}->to_xml_element);
    ok($from_element_ds, 'Created dataset from XML element');

    # Check ds and from element ds
    for my $attr (qw/ name row_name headers rows attributes /) {
        is_deeply($from_element_ds->$attr, $ds->$attr, $attr);
    }

    return 1;
}

sub test05_validate_aryref_and_xml_string : Test(4) { 
    my $self = shift;

    # aryref
    ok(
        !$self->test_class->_validate_aryref(
            name => 'data',
            value => undef,
            method => '_validate_aryref',
        ),
        '_validate_aryref failed as expected - no value'
    );
    ok(
        !$self->test_class->_validate_aryref(
            name => 'data',
            value => 'string',
            method => '_validate_aryref',
        ),
        '_validate_string_for_xml failed as expected - not aryref'
    );

    # xml
    ok(
        !$self->test_class->_validate_string_for_xml(
            name => 'data',
            value => undef,
            method => '_validate_string_for_xml',
        ),
        '_validate_string_for_xml failed as expected - no value'
    );
    ok(
        !$self->test_class->_validate_aryref(
            name => 'data',
            value => 'string_w_under_scores',
            method => '_validate_string_for_xml',
        ),
        '_validate_string_for_xml failed as expected - value has underscores'
    );

    return 1;
}


sub test06_rows : Tests(3) {
    my $self = shift;

    my $ds = $self->{_object};
    is_deeply([$ds->get_row_values_for_header('assembled')], [5], 'get_row_values_for_header');
    ok(!$ds->get_row_values_for_header(), 'get_row_values_for_header failed as expected - no header');
    ok(!$ds->get_row_values_for_header('not there'), 'get_row_values_for_header failed as expected - header not found');

    return 1;
}

#######################################################################

package Genome::Report::Email::Test;

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper 'Dumper';
use Test::More;

sub test_report_dir {
    return '/gsc/var/cache/testsuite/data/Genome-Report/Build_Start';
}

sub test01_send_report : Test(5) {
    my $self = shift;

    use_ok('Genome::Report::Email');
    
    my $report = Genome::Report->create_report_from_directory(
        $self->test_report_dir,
    ) or die "Can't get report\n";


    my %valid_params = (
        report => $report,
        to => [Genome::Config->user_email], # can be string or aryref
        xsl_files => [ $report->generator->get_xsl_file_for_html ],
    );

    #< Valid >#
    my $valid = Genome::Report::Email->send_report(%valid_params);
    ok($valid, 'Sent report');

    #< Invalid >#
    for my $attr (qw/ to report xsl_files /) {
        my $val = delete $valid_params{$attr};
        my $invalid = Genome::Report::Email->send_report(%valid_params);
        ok(!$invalid, 'Failed as expected - no '.$attr);
        $valid_params{$attr} = $val;
    }

    return 1;
}

#######################################################################

package Genome::Report::FromSeparatedValueFileTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Test::More;
use Storable 'retrieve';

sub generator {
    return $_[0]->{_object};
}

sub test_class_sub_dir {
    return 'Genome-Utility-IO';
}

sub test_class {
    return 'Genome::Report::FromSeparatedValueFile';
}

sub _svr {
    my $self = shift;

    unless ( $self->{_svr} ) {
        $self->{_svr} = Genome::Utility::IO::SeparatedValueReader->create(
            input => $self->dir.'/albums.csv',
        ) or die;
    }

    return $self->{_svr};
}

sub params_for_test_class {
    my $self = shift;
    return (
        name => 'Report from Albums SVF',
        description => 'Albums on Hand Today',
        svr => $self->_svr,
    );
}

sub required_attrs {
    return (qw/ name description svr /);
}

sub test_01_generate_report : Test(2) {
    my $self = shift;

    can_ok($self->generator, '_add_to_report_xml');

    my $report = $self->generator->generate_report;
    ok($report, 'Generated report');
    print $report->xml_string;
    #print Dumper($report);

    return 1;
}

#######################################################################

package Genome::Report::FromLegacyTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Test::More;
use Storable 'retrieve';

sub generator {
    return $_[0]->{_object};
}

sub test_class {
    return 'Genome::Report::FromLegacy';
}

sub legacy_report_directory {
    return $_[0]->dir.'/Legacy_Report';
}

sub legacy_properties_file {
    return $_[0]->legacy_report_directory.'/properties.stor';
}

sub params_for_test_class {
    my $self = shift;
    return (
        properties_file => $self->legacy_properties_file,
    );
}

sub required_params_for_class {
    return (qw/ properties_file /);
}

sub test_01_generate_report : Test(1) {
    my $self = shift;

    my $report = $self->generator->generate_report;
    ok($report, 'Generated report');

    return 1;
}

#######################################################################

package Genome::Report::XSLT::Test;

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper 'Dumper';
use Genome::Report;
use Test::More;

sub dir {
    return '/gsc/var/cache/testsuite/data/Genome-Report-XSLT';
}

sub xsl_file {
    return $_[0]->dir.'/AssemblyStats.txt.xsl';
}

sub test01_transform_report : Test(7) {
    my $self = shift;

    use_ok('Genome::Report::XSLT');
    
    my $report = Genome::Report->create_report_from_directory($self->dir.'/Assembly_Stats')
        or die "Can't get report\n";
    my $xslt_file = $self->xsl_file;
        
    #< Valid >#
    my $xslt = Genome::Report::XSLT->transform_report(
        report => $report,
        xslt_file => $xslt_file,
    );
    ok($xslt, 'transformed report');
    ok($xslt->{content}, 'Content');
    #print $xslt->{content};
    ok($xslt->{encoding}, 'Encoding');
    is($xslt->{media_type}, 'text/plain', 'Media type');
    
    #< Invalid >#
    # no report
    my $no_report = Genome::Report::XSLT->transform_report(
        xslt_file => $xslt_file,
    );
    ok(!$no_report, "Failed as expected, w/o report");
    # no xslt_file
    my $no_xslt_file = Genome::Report::XSLT->transform_report(
        report => $report,
    );
    ok(!$no_xslt_file, "Failed as expected, w/o xslt file");

    return 1;
}

sub test02_output_type : Tests(4) {
    my $self = shift;

    my %media_and_output_types = (
        'application/xml' => 'xml',
        'text/plain' => 'txt',
        'text/html' => 'html',
        rrrr => '',
    );

    for my $media_type ( keys %media_and_output_types ) {
        is(
            Genome::Report::XSLT->_determine_output_type($media_type), 
            $media_and_output_types{$media_type},
            "Media ($media_type) to output type ($media_and_output_types{$media_type})"
        );
    }

    return 1;
}

#######################################################################

package Genome::Report::Command::Test;

use strict;
use warnings;

use base 'Test::Class';

require Cwd;
use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Report::Command';
}

sub test01_use : Test(1) {
    my $self = shift;

    use_ok( $self->test_class );

    return 1;
}
 
#######################################################################

package Genome::Report::Command::Email::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Report::Command::Email';
}

sub valid_param_sets {
    return (
        {
            report_directory => Genome::Report::XSLT::Test->dir.'/Assembly_Stats',
            xsl_files => Genome::Report::XSLT::Test->xsl_file,
            to => Genome::Config->user_email,
        },
    );
}

sub startup : Tests(startup) {
    my $self = shift;

    # overload 'Close' to not send the mail, but to cancel it 
    no warnings;
    *Mail::Sender::Close = sub{ my $sender = shift; $sender->Cancel; return 1; };

    return 1;
}

#######################################################################

package Genome::Report::Command::GetDataset::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';

sub test_class {
    return 'Genome::Report::Command::GetDataset';
}

sub valid_param_sets {
    return map {
        {
            report_directory => Genome::Report::XSLT::Test->dir.'/Assembly_Stats',
            dataset_name => 'stats',
            output_type => $_,
        }
    } $_[0]->test_class->output_types;
}

#######################################################################

package Genome::Report::Command::ListDatasets::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';

sub test_class {
    return 'Genome::Report::Command::ListDatasets';
}

sub valid_param_sets {
    return (
        {
            report_directory => Genome::Report::XSLT::Test->dir.'/Assembly_Stats',
        },
    );
}

#######################################################################

package Genome::Report::Command::Xslt::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestCommandBase';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Test::More;

sub test_class {
    return 'Genome::Report::Command::Xslt';
}

sub valid_param_sets {
    return (
        {
            report_directory => Genome::Report::XSLT::Test->dir.'/Assembly_Stats',
            xsl_file => Genome::Report::XSLT::Test->xsl_file,
            output_file => $_[0]->tmp_dir.'/Assembly_Stats.txt',
            after_execute => sub{
                my ($self, $xslt) = @_;
                ok(-e $xslt->output_file, 'Output file exists');
                return 1;
            },
        },
    );
}

sub startup : Test(startup => no_plan) {
    my $self = shift;

    no warnings;
    local *Genome::Report::XSLT::transform_report = sub { # so we don't test this twice
        my $content = <<EOS;

Summary for Amplicon Assembly Model (Name:  Build Id:)

------------------------
Stats
------------------------

Attempted
Assembled 5
Assembly Success 100.00%

Length Average 1399
Length Median 1396
Length Maximum 1413
Length Minimum 1385

Quality Base Average 62.75
Quality >= 20 per Assembly 1349.80

Reads Assembled 20
Reads Total 30
Reads Assembled Success 66.67%
Reads Assembled Average 4.00
Reads Assembled Median 3
Reads Assembled Maximum 6
Reads Assembled Minimum 3

------------------------

For full report, including quality hisotgram go to:
http://

EOS
        return { 
            media_type => 'text/plain',
            output_type => 'txt',
            content => $content,
        };
    };
    
    return 1;
}

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

