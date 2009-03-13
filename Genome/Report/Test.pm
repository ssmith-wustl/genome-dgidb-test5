package Genome::Report::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub report {
    return $_[0]->{_object};
}

sub test_class {
    'Genome::Report';
}

sub params_for_test_class {
    return (
        name => 'Test Report',
        parent_directory => $_[0]->tmp_dir,
    );
}

sub report_data {
    return { 
        description => 'html test report',
        html => '<html><title>Report</title></html>',
        csv => "c1,c2\nr1,r2\n",
    };
}

sub test01_save_report : Test(3) {
    my $self = shift;

    # Save w/o data - fails
    ok(!$self->report->save, 'Failed as expected - save report w/o data');
    # Set data
    ok($self->report->set_data( $self->report_data ), 'Set data');
    # Save for real
    ok($self->report->save, 'Saved report');
    
    return 1;
}

sub test02_get_from_cache : Test(3) {
    my $self = shift;
    
    my $report = $self->test_class->get(
        $self->params_for_test_class,
    );
    ok($report, 'Got report from cache');
    is(scalar(Genome::Report->all_objects_loaded), 1, 'Only one report in cache');
    is_deeply(
        $report->get_data,
        $self->report->get_data,
        'Report data matches',
    );

    return 1;
}

sub test03_get_report : Test(5) {
    my $self = shift;
    
    # Get 
    my $report = $self->test_class->get(
        name => 'Test Report 1',
        parent_directory => $self->dir,
    );
    ok($report, 'Got report using get');
    is($report->name, 'Test Report 1', 'Report has correct name');
    $report->delete; # remove from cache
    
    # Get it w/ parent dir
    my @reports = $self->test_class->get_reports_in_parent_directory($self->dir);
    @reports = $self->test_class->get_reports_in_parent_directory($self->dir);
    is(@reports, 2, 'Got two reports using get_reports_in_parent_directory');
    is($reports[0]->name, 'Test Report 1', 'Report 1 has correct name');
    is($reports[1]->name, 'Test Report 2', 'Report 2 has correct name');

    return 1;
}

sub test04_other_get_and_create_fails : Tests {
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

package Genome::Report::TestClass;

use strict;
use warnings;

class Genome::Report::TestClass {
    is => 'Genome::Report',
};

#######################################################################

package Genome::Report::CsvTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Test::More;
use Storable 'retrieve';

sub report {
    return $_[0]->{_object};
}

sub test_class_sub_dir {
    return 'Genome-Model-Report';
}

sub test_class {
    return 'Genome::Report::Csv';
}

sub params_for_test_class {
    my $self = shift;
    return (
        headers => $self->_headers,
        file => $self->dir.'/myalbums.html',
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

