#!/gsc/bin/perl

use warnings FATAL => 'all';
use strict;

use GSCApp;
use GSCApp::Test;

plan tests => 2;

my $wb = GSCApp::Wikibot->new();

ok($wb, 'Logging Wikibot in');

my $src = $wb->get_page_source(page => 'Main Page');

ok($src, 'Retrieving main page');



