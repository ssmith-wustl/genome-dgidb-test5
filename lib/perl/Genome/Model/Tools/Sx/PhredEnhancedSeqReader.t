#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Tools::Sx::PhredEnhancedSeqReader') or die;

my $reader = Genome::Model::Tools::Sx::PhredEnhancedSeqReader->create(file => '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sx/PhredReaderWriter/in.efasta');
ok($reader, 'create');
my $seq = $reader->read;
ok($seq, 'got seq');
is(
    $seq->{seq}, 
    'GGGGAGGGGAAAAAAAAAAGGGGAAAAAAAAAAAAGGGGaGGGGAAAAAAAAGGGGTTCCTT',
    'sequence matches',
);

done_testing();
exit;

