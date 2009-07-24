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

sub test00_attrs : Test(8) {
    my $self = shift;

    my $report = $self->report;

    # meta
    my %report_meta = $self->_report_meta_hash;
    for my $attr ( keys %report_meta ) {
        is_deeply($report->$attr, $report_meta{$attr}, $attr);
    }
    
    # datasets
    my @datasets = $report->get_dataset_nodes;
    ok(@datasets, 'datasets') or die;
    my ($stats) = $report->get_dataset_nodes_for_name('stats');
    ok($stats, 'stats dataset') or die;
    is($datasets[0]->nodeName, $stats->nodeName, 'dataset name');

    return 1;
}

sub test01_save_report : Test(5) {
    my $self = shift;

    # Save - fails
    ok(!$self->report->save, 'Failed as expected - no directory');
    ok(!$self->report->save('invalid_directory'), 'Failed as expected - invalid directory');

    # Save
    ok($self->report->save( $self->tmp_dir ), 'Saved report to tmp dir');
    
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

package Genome::Report::GeneratorTest;

# FIXME does not fully test the generator!

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Report::Generator';
}

sub test01_generate_report : Test(1) {
    my $self = shift;

    can_ok($self->test_class, 'generate_report');

    return 1;
}

sub test02_validate_aryref : Test(2) { 
    my $self = shift;

    ok(
        !$self->test_class->_validate_aryref(
            name => 'data',
            value => undef,
            method => 'test validating the _validate_aryref',
        ),
        'Failed as expected - no value'
    );
    ok(
        !$self->test_class->_validate_aryref(
            name => 'data',
            value => 'string',
            method => 'test validating the _validate_aryref',
        ),
        'Failed as expected - value not aryref headers'
    );

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

    can_ok($self->generator, '_generate_data');

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
    #print Dumper($report); $report->save('/gscuser/ebelter/Desktop/reports', 1);

    return 1;
}

#######################################################################

package Genome::Utility::IO::HtmlTableWriterTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Test::More;
use Storable 'retrieve';

sub svw {
    return $_[0]->{_object};
}

sub test_class_sub_dir {
    return 'Genome-Utility-IO';
}

sub test_class {
    return 'Genome::Utility::IO::HtmlTableWriter';
}

sub params_for_test_class {
    my $self = shift;
    return (
        headers => $self->_headers,
        output => $self->dir.'/myalbums.html',
        #output => $self->tmp_dir.'/albums.html',
    );
}

sub required_attrs {
    return (qw/ headers /);
}

sub _headers {
    my $self = shift;

    $self->_set_headers_and_rows unless $self->{_headers};

    return $self->{_headers};
}

sub _rows {
    my $self = shift;

    $self->_set_headers_and_rows unless $self->{_headers};

    return $self->{_rows};
}

sub _albums_csv {
    return $_[0]->dir.'/albums.csv';
}

sub _set_headers_and_rows {
    my $self = shift;

    my $fh = Genome::Utility::FileSystem->open_file_for_reading( $self->_albums_csv )
        or die;
    my $header_line = $fh->getline;
    chomp $header_line;
    $self->{_headers} = [ split(',', $header_line) ];
    while ( my $line = $fh->getline ) {
        chomp $line;
        push @{$self->{_rows}}, [ split(',', $line) ];
    }
    
    return 1;
}

sub test01_write_and_compare : Test(1) {
    my $self = shift;

    my $svw = $self->svw;
    for my $row ( @{$self->_rows} ) {
        $svw->write_one($row);
    }

    is(compare($svw->get_original_output, $self->_albums_csv, ), 0, 'Compared generated and files');

    return 1;
}

#######################################################################

package Genome::Report::XSLTTest;

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper 'Dumper';
use Genome::Report;
use Test::More;

sub dir {
    return '/gsc/var/cache/testsuite/data/Genome-Report-XSLT';
}

sub test01_transform_report : Test(4) {
    my $self = shift;

    use_ok('Genome::Report::XSLT');
    
    my $report = Genome::Report->create_report_from_directory($self->dir.'/Assembly_Stats')
        or die "Can't get report\n";
    my $xslt_file = $self->dir.'/AssemblyStats.txt.xsl';
        
    # Valid
    my $txt = Genome::Report::XSLT->transform_report(
        report => $report,
        xslt_file => $xslt_file,
    );
    ok($txt, 'transformed report');
    #print $txt,"\n";
    
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

