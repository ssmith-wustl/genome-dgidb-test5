#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 3;

BEGIN {
    use_ok('Genome::Model::Tools::Velvet::ToAce');
}

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Velvet/ToAce';
my $file = $test_dir.'/velvet_asm_1.afg';

my $ta = Genome::Model::Tools::Velvet::ToAce->create(
    afg_file    => $file,
    out_acefile => $test_dir.'/velvet_asm.ace',
);

ok($ta, 'to-ace creates ok');
ok($ta->execute, 'velvet to-ace runs ok');

exit;
