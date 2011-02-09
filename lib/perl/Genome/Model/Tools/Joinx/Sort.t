#!/usr/bin/env perl

use above 'Genome';
use Test::More tests => 4;
use File::Basename qw/dirname/;

my $pkg = 'Genome::Model::Tools::Joinx::Sort';
use_ok($pkg);

my $input = __FILE__ . ".input";
my $expected = __FILE__ . ".expected";
my $tmpdir = File::Temp::tempdir('joinx-sort-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $output = join('/', $tmpdir, 'output');

my $cmd = $pkg->create(
    input_files => [$input],
    output_file => $output
    );

ok($cmd, 'Created command');
ok($cmd->execute, 'Executed command');

my $diff = Genome::Sys->diff_file_vs_file($output, $expected);
ok(!$diff, 'output matched expected result') or diag("diff results:\n" . $diff);

done_testing();
