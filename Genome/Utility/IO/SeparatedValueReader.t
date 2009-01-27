#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More tests => 14;
use Storable 'retrieve';

use_ok('Genome::Utility::IO::SeparatedValueReader');

my $dir = '/gsc/var/cache/testsuite/data/Genome-Utility-IO';
ok(-d $dir, "Test dir ($dir) exists");
my $albums = retrieve($dir.'/albums.stor');
ok($albums, "Got albums from stor file")
    or die;

#< SVR - HEADERS IN FILE >#
my $svr = Genome::Utility::IO::SeparatedValueReader->create(
    input => $dir.'/albums.csv', # w/ headers
);
ok($svr, 'Created SVR');
my @albums;
while ( my $album = $svr->next ) { push @albums, $album }
is_deeply(\@albums, $albums->{albums}, 'Albums from SVR (method: next) match expected albums');
is($svr->line_number, 5, 'Line number incremented successfully');
ok($svr->reset, 'reset');
is($svr->line_number, 1, 'Reset to line 1');
$svr->delete;

#< SVR - NO HEADERS IN FILE >#
$svr = Genome::Utility::IO::SeparatedValueReader->create(
    input => $dir.'/albums.no_headers.csv', # w/o headers
    headers => $albums->{headers},
);
ok($svr, 'Created SVR');
@albums = $svr->all;
is_deeply(\@albums, $albums->{albums}, 'Albums from SVR (method: all) match expected albums');
$svr->delete;

#< SVR - REGEXP >#
my $svr = Genome::Utility::IO::SeparatedValueReader->create(
    input => $dir.'/albums.test_regexp.csv', # w/ headers
    separator => ',+',
    is_regex => 1,

);
ok($svr, 'Created SVR');
@albums = $svr->all;
is_deeply(\@albums, $albums->{albums}, 'Albums from SVR (regexp) match expected albums');
$svr->delete;

#< INVALID PARAMS >#
$svr = Genome::Utility::IO::SeparatedValueReader->create(
    input => $dir.'/albums.no_headers.csv', # w/o headers
    headers => [qw/ not the right number of headers /],
);
ok($svr, 'Created SVR to test different header v. value count');
ok(!$svr->next, 'Failed as expected - next');

exit;

#########

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

