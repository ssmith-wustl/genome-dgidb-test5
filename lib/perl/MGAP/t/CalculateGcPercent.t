use strict;
use warnings;

use above "MGAP";
use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 5;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::CalculateGcPercent');
}

my $seq1 = Bio::Seq->new(
                         -id   => 'TST000001',
                         -desc => 'GC Test Sequence',
                         -seq  => 'GATNNNNNNNNNNNNNTACA',
                        );

my $seq2 = Bio::Seq->new(
                         -id   => 'TST000002',
                         -desc => 'GC Test Sequence',
                         -seq  => 'GATNNNNNNNNNNNNNTACA',
                        );
                        
my $temp_fh = File::Temp->new();
my $seqio   = Bio::SeqIO->new(-fh => $temp_fh, -format => 'Fasta');

$seqio->write_seq($seq1);
$seqio->write_seq($seq2);
$seqio->close();
$temp_fh->close();

my $command = MGAP::Command::CalculateGcPercent->create('fasta_files' => [ $temp_fh->filename() ]);
isa_ok($command, 'MGAP::Command::CalculateGcPercent');

ok($command->execute());

# range is limited to 30-70 for now
#is($command->gc_percent(), 28.6);
is($command->gc_percent(), 30.0);
