#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gsc/scripts/lib/perl';

my $cmd='/gsc/scripts/bin/gt auto-add-reads';
system($cmd);

1;