#! perl
# Test script for GSCApp::Path

use warnings;
use strict;
use Test::More skip_all => "TEST BROKEN"; # tests => 34;

BEGIN { use_ok('GSCApp::Path'); }

# set prefix
my $prefix = '/gsc/scripts';
ok(App::Path->prefix($prefix), "set prefix $prefix");

# check for know non-var directories
my %known = (doc => 'info', intweb => 'html', lib => 'perl', share => 'gsc-login');
while (my ($d, $s) = each(%known)) {
    my $p = "$prefix/$d/$s";
    # more than one may exist
    my @ps = grep { $_ eq $p } App::Path->get_path($d, $s);
    ok(@ps == 1, 'got one path');
    is($ps[0], $p, "got path $p");
}

# check var directories
foreach my $d qw(cache lib lock log run spool state tmp) {
    my $p = "/gsc/var/$d";
    # more than one may exist
    my @ps = grep { $_ eq $p } App::Path->get_path('var', $d);
    ok(@ps == 1, 'got one path');
    is($ps[0], $p, "got path $p");
}

# make sure these still work
while (my ($d, $s) = each(%known)) {
    my $p = "$prefix/$d/$s";
    # more than one may exist
    my @ps = grep { $_ eq $p } App::Path->get_path($d, $s);
    ok(@ps == 1, 'got one path');
    is($ps[0], $p, "got path $p");
}

exit(0);

# $Header$
