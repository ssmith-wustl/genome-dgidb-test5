package Genome::Report::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub report {
    return $_[0]->{_object};
}

sub reports_dir {
    return $_[0]->dir.'/reports';
}

sub test_class {
    'Genome::Report';
}

sub params_for_test_class {
    return (
        name => 'Test Report',
        data => $_[0]->report_data,
    );
}

sub report_data {
    return {
        generator => 'Genome::Report::Generator',
        generator_params => {
            who => 'employees',
            what => [qw/ name email /],
        },
        date => '2009-03-16 15:13:20',
        description => 'html test report',
        html => '<html><title>Report</title><h1>GC Employees</h1><br><table><th>Name</th><th>Email</th><tr><td>Rick Wilson</td><td>rwilson@genome.wustl.edu</td></tr></table></html>',
        csv => "Name,Email\nRick Wilson,rwilson\@genome.wustl.edu\n",
    };
}

sub test01_save_report : Test(4) {
    my $self = shift;

    # Save - fails
    ok(!$self->report->save, 'Failed as expected - no directory');
    ok(!$self->report->save('invalid_directory'), 'Failed as expected - invalid directory');

    # Save
    ok($self->report->save( $self->tmp_dir ), 'Saved report to tmp dir');
    
    # Resave - fails
    ok(!$self->report->save( $self->tmp_dir ), 'Failed as expected - resave report');
    
    return 1;
}

sub test02_create_report_from_directories : Test(9) {
    my $self = shift;
    
    # Get it w/ parent dir
    my @reports = $self->test_class->create_reports_from_parent_directory( $self->reports_dir );
    is(@reports, 2, 'Got two reports using create_reports_from_parent_directory');
    is($reports[0]->name, 'Test Report 1', 'Report 1 has correct name');
    is($reports[1]->name, 'Test Report 2', 'Report 2 has correct name');

    # Check data
    my $data = $self->report_data;
    for my $type (qw/ generator generator_params description html csv xml /) {
        my $method = 'get_'.$type;
        is_deeply($reports[0]->$method, $data->{$type}, $reports[0]->name." $type matches");
    }

    return 1;
}

sub test03_other_get_and_create_fails {# : Tests {
    my $self = shift;
    
    my $valid_name = 'Test Report';
    my $valid_dir = $self->dir;

    #< Get and create funnel to same method
    ok( # invalid parent_directory
        !$self->test_class->get(
            name => $valid_name,
            parent_directory => 'no_way_this_dir_exists',
        ),
        'Failed as expected - get report w/ invalid parent_directory',
    );
    ok( # w/ data
        !$self->test_class->get(name => $valid_name, parent_directory => $valid_dir, data => { key => 'value' }),
        'Failed as expected - tried to get report w/ data',
    );


    return 1;
}

#######################################################################

package Genome::Report::GeneratorTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Report::Generator';
}

sub params_for_test_class {
    return (
        name => 'Generator Tester',
    );
}

sub headers {
    return [qw/ Assembled Attempted Success /];
}

sub data {
    return [ [qw/ 5 5 100% /] ];
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
            method => '_generate_vertical_html_table',
        ),
        'Failed as expected - no value'
    );
    ok(
        !$self->test_class->_validate_aryref(
            name => 'data',
            value => 'string',
            method => '_generate_vertical_html_table',
        ),
        'Failed as expected - value not aryref headers'
    );

    return 1;
}

sub test03_generate_cvs : Test(1) {
    my $self = shift;

    my $svs =  $self->test_class->_generate_csv_string(
        headers => $self->headers,
        data => $self->data,
    );
    ok($svs, 'Generated csv string');
    #print Dumper($svs);

    return 1;
}

sub test04_generate_html_tables : Test(2) {
    my $self = shift;

    # note - not testing if headers and data are included, testing the _validate_aryref method above
    
    my $table =  $self->test_class->_generate_html_table(
        headers => $self->headers,
        data => $self->data,
    );
    ok($table, 'Generated html table');
    #print Dumper($table);

    my $vert_table = $self->test_class->_generate_vertical_html_table(
        headers => [qw/ Category Assembly1 /],
        horizontal_headers => $self->headers,
        data => $self->data,
    );
    ok($vert_table, 'Generated vertical html table');

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

sub params_for_test_class {
    my $self = shift;
    return (
        name => 'Report from Albums SVF',
        file => $self->dir.'/albums.csv',
        description => 'Albums on Hand Today',
    );
}

sub required_attrs {
    return (qw/ name file description /);
}

sub test_01_generate_report : Test(2) {
    my $self = shift;

    can_ok($self->generator, '_generate_data');

    my $report = $self->generator->generate_report;
    ok($report, 'Generated report');
    print Dumper($report);

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

