use strict;
use warnings;

use above 'EGAP';

use File::Temp qw(tempdir);
use Test::More tests => 6;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::GetFastaFiles');
}

my $test_dir = "/gsc/var/cache/testsuite/running_testsuites/";
my $test_output_dir = tempdir('EGAP-Command-GetFastaFiles-XXXXXX',
    DIR => $test_dir,
    CLEANUP => 1,
);
chmod(0755, $test_output_dir);

my $command = EGAP::Command::GetFastaFiles->create(
    seq_set_id => 73,
    output_directory => $test_output_dir,
);

isa_ok($command, 'EGAP::Command::GetFastaFiles');

ok($command->execute());
my @files = @{$command->fasta_files()};

ok(scalar(@files) == 1);
ok(unlink(@files) == 1);
