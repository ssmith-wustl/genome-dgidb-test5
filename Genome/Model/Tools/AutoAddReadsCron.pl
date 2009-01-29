#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gsc/scripts/lib/perl';

my $cmd='/gsc/scripts/bin/gt auto-add-reads';
$ENV{'PERL5LIB'} = '/gsc/scripts/lib/perl/:' . $ENV{'PERL5LIB'};
system($cmd);

1;