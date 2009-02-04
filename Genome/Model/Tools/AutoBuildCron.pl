#!/gsc/bin/perl

use strict;
use warnings;

use Genome;

#use lib '/gsc/scripts/lib/perl';
#$ENV{'PERL5LIB'} = '/gsc/scripts/lib/perl/:' . $ENV{'PERL5LIB'};

my $results = Genome::Model::Tools::AutoBuild->execute();

1;