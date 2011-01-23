package Genome::Utility::IO::SeparatedValueTestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Storable 'retrieve';

sub svo {
    return $_[0]->{_object};
}

sub test_class_sub_dir {
    return 'Genome-Utility-IO';
}

sub required_attrs {
    return;
}

#< >#
sub _albums_csv {
    return $_[0]->dir.'/albums.csv';
}

sub _albums_stor {
    return $_[0]->dir.'/albums.stor';
}

sub _albums_no_headers {
    return $_[0]->dir.'/albums.no_headers.csv';
}

sub _albums_regexp {
    return $_[0]->dir.'/albums.test_regexp.csv';
}

sub _stored_albums {
    my $self = shift;

    unless ( $self->{_albums} ) {
        my $data = retrieve($self->_albums_stor)
            or die "Can't get stored albums\n";
        $self->{_albums} = $data;
    }

    return $self->{_albums};
}

###################################################################

package Genome::Utility::IO::SeparatedValueWriterTest;

use strict;
use warnings;

use base 'Genome::Utility::IO::SeparatedValueTestBase';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Test::More;

sub test_class {
    return 'Genome::Utility::IO::SeparatedValueWriter';
}

sub params_for_test_class {
    my $self = shift;
    return (
        #output => $self->dir.'/myalbums.csv',
        output => $self->tmp_dir.'/albums.csv',
        headers => $self->_headers,
    );
}

sub _headers {
    my $self = shift;

    $self->_set_headers_and_data unless $self->{_headers};

    return $self->{_headers};
}

sub _data {
    my $self = shift;

    $self->_set_headers_and_data unless $self->{_headers};

    return $self->{_data};
}

sub _set_headers_and_data {
    my $self = shift;

    my $fh = Genome::Sys->open_file_for_reading( $self->_albums_csv )
        or die;
    my $header_line = $fh->getline;
    chomp $header_line;
    $self->{_headers} = [ split(',', $header_line) ];
    while ( my $line = $fh->getline ) {
        chomp $line;
        my %data;
        @data{ @{$self->{_headers}} } = split(',', $line);
        push @{$self->{_data}}, \%data;
    }

    return 1;
}

sub test01_write_and_compare : Test(1) {
    my $self = shift;

    for my $data ( @{$self->_data} ) {
        $self->svo->write_one($data);
    }

    is(compare($self->svo->get_original_output, $self->_albums_csv, ), 0, 'Compared generated and files');

    return 1;
}

sub test02_write_one_fails : Tests {
    my $self = shift;

    my %fails = (
        'undef' => undef,
        'empty hash ref' => {},
        'not a hash ref' => 'a string',
        'different headers' => { different => 'headers' },
    );
    
    for my $desc ( keys %fails ) {
        ok(!$self->svo->write_one($fails{$desc}), "Failed as expected, tried to 'write one' w/ $desc");
    }

    return 1;
}

#######################################################################

package Genome::Utility::IO::SeparatedValueReaderTest;

use strict;
use warnings;

use base 'Genome::Utility::IO::SeparatedValueTestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Utility::IO::SeparatedValueReader';
}

sub params_for_test_class {
    my $self = shift;
    return (
        input => $self->_albums_csv,
    );
}

sub required_attrs {
    return (qw/ input /);
}

sub test01_read_and_compare : Test(4) {
    my $self = shift;

    my $stored_albums = $self->_stored_albums;
    
    my @albums;
    while ( my $album = $self->svo->next ) { push @albums, $album }
    is_deeply(\@albums, $stored_albums->{albums}, 'Albums from SVR (method: next) match expected albums');
    is($self->svo->line_number, 5, 'Line number incremented successfully');
    ok($self->svo->reset, 'reset');
    is($self->svo->line_number, 1, 'Reset to line 1');

    return 1;
}

sub test02_headers_not_in_file : Test(2) {
    my $self = shift;

    my $stored_albums = $self->_stored_albums;

    my $svr = $self->test_class->create(
        input => $self->_albums_no_headers, # w/o headers
        headers => $stored_albums->{headers},
    );
    ok($svr, 'Created SVR w/o headers');
    my @albums = $svr->all;
    is_deeply(\@albums, $stored_albums->{albums}, 'Albums from SVR (method: all) match expected albums');
    $svr->delete;

    return 1;
}

sub test03_regexp_separator : Test(2) {
    my $self = shift;

    my $stored_albums = $self->_stored_albums;

    my $svr = $self->test_class->create(
        input => $self->_albums_regexp, # w/ headers
        separator => ',+',
        is_regex => 1,

    );
    ok($svr, 'Created SVR');
    my @albums = $svr->all;
    is_deeply(\@albums, $stored_albums->{albums}, 'Albums from SVR (regexp) match expected albums');

    return 1;
}

sub test04_create_with_different_number_of_headers_than_values_in_file : Test(2) {
    my $self = shift;

    my $svr = $self->test_class->create(
        input => $self->_albums_no_headers, # w/o headers
        headers => [qw/ not the right number of headers /],
    );
    ok($svr, 'Created SVR to test different header v. value count');
    ok(!$svr->next, 'Failed as expected - next');

    return 1;
}

# This should fail because we ignore extra columns but we dont have the minimum
sub test05_create_with_too_few_data_columns_while_ignore_extra_columns : Test(2) {
    my $self = shift;

    my $svr = $self->test_class->create(
        input => $self->_albums_no_headers, # w/o headers
        headers => [qw/ dont have data to fill all these columns /],
        ignore_extra_columns => 1,
    );
    ok($svr, 'Created SVR to test too few columns while ignoring extra columns');
    ok(!$svr->next, 'Failed as expected - next');

    return 1;
}

# This should succeed because we ignore extra columns
sub test05_create_with_too_many_data_columns_while_ignore_extra_columns : Test(2) {
    my $self = shift;

    my $svr = $self->test_class->create(
        input => $self->_albums_no_headers, # w/o headers
        headers => [qw/ have enough data /],
        ignore_extra_columns => 1,
    );
    ok($svr, 'Created SVR to test too many columns while ignoring extra columns');
    ok($svr->next, 'Succeeded as expected');

    return 1;
}



1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
