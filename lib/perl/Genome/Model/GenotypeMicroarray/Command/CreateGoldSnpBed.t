#!/usr/bin/env perl

use above 'Genome';
use Test::More tests => 4;

my $pkg = 'Genome::Model::GenotypeMicroarray::Command::CreateGoldSnpBed';
use_ok($pkg);

my $input = __FILE__ . ".input";
my $expected = __FILE__ . ".expected";
my $tmpdir = File::Temp::tempdir('create-gold-snp-bed-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $output = join('/', $tmpdir, 'output');

my $ref = Genome::Model::Build::ImportedReferenceSequence->get(
    name => "NCBI-human-build36"
    );

my $cmd = $pkg->create(
    input_file => $input,
    output_file => $output,
    reference => $ref,
    );

ok($cmd, 'Created command');
ok($cmd->execute, 'Executed command');

my $diff = Genome::Sys->diff_file_vs_file($output, $expected);
ok(!$diff, 'output matched expected result') or diag("diff results:\n" . $diff);

done_testing();
