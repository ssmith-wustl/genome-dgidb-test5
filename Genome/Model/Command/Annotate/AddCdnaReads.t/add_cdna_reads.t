#!/gsc/bin/perl

use strict;
use warnings;

###############

package AddCdnaReads::Test;

use base 'Test::Class';

use Test::More;
use Test::Differences;
#use Test::Files;

sub execute : Tests
{
    my $self = shift;

    my $in = 'report';

    #is((system "genome-model annotate add-cdna-reads --outfile $infile_gm --read-hash-cdna ../cDNA_unique_readcount_allcdna18.csv --read-hash-relapse-cdna ../cDNA_unique_readcount_allcdna18.csv --read-hash-unique-cdna ../cDNA_unique_readcount_allcdna18.csv --read-hash-unique-dna ../cDNA_unique_readcount_allcdna18.csv"), 0, "Executed");
    is((system "genome-model annotate add-cdna-reads --input $in"), 0, "Executed");
 
    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AddCdnaReads::Test /);

exit 0;

