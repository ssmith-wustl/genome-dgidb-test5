use strict;
use warnings;

use Workflow;

use Test::More tests => 6;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::GetFastaFiles');
}

my $command = MGAP::Command::GetFastaFiles->create('seq_set_id' => 43);
isa_ok($command, 'MGAP::Command::GetFastaFiles');

ok($command->execute());
my @files = @{$command->fasta_files()};

ok(scalar(@files) == 1263);
ok(unlink(@files) == 1263);

