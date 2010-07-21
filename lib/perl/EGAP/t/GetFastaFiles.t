use strict;
use warnings;

use above 'EGAP';

use Test::More tests => 6;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::GetFastaFiles');
}

my $command = EGAP::Command::GetFastaFiles->create(
                                                   'seq_set_id' => 73,
                                                  );

isa_ok($command, 'EGAP::Command::GetFastaFiles');

ok($command->execute());
my @files = @{$command->fasta_files()};

ok(scalar(@files) == 1);
ok(unlink(@files) == 1);
