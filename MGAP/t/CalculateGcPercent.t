use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 5;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::CalculateGcPercent');
}

my $seq = Bio::Seq->new(
                        -id   => 'TST000001',
                        -desc => 'GC Test Sequence',
                        -seq  => 'GATNNNNNNNNNNNNNTACA',
                       );

my $temp_fh = File::Temp->new();
my $seqio   = Bio::SeqIO->new(-fh => $temp_fh, -format => 'Fasta');

$seqio->write_seq($seq);
$seqio->close();
$temp_fh->close();

my $command = MGAP::Command::CalculateGcPercent->create('fasta_files' => [ $temp_fh->filename() ]);
isa_ok($command, 'MGAP::Command::CalculateGcPercent');

ok($command->execute());

is($command->gc_percent(), 28.6);
