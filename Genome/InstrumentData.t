#!/gsc/bin/perl

use strict;
use warnings;

BEGIN { $ENV{UR_DBI_NO_COMMIT} = 1 };
use above "Genome";

use Test::More tests => 1; 

my %seq_plats_and_ids = (
    454     => '2403581188',
    sanger  => '03may05.868pmaa1',
    solexa  => '2338813239',
);

my @rcs = Genome::InstrumentData->get([ values %seq_plats_and_ids ]);
is(scalar(@rcs), 3, "got 3 objects");

#$HeadURL$
#$Id$
