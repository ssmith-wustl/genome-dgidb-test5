use strict;
use warnings;

use Workflow;

use Bio::SeqFeature::Generic;

use Test::More tests => 6;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::UploadResult');
}

my $feature = Bio::SeqFeature::Generic->new(
                                            -seq_id     => 'ESCCOLD8X_Contig766.1',
                                            -start      => 2112,
                                            -end        => 2191,
                                            -strand     => 1,
                                            -source_tag => 'trnascan',
                                            -tag => { 'Codon' => 'TAG', 'AminoAcid' => 'Leu' },
                                           );
              
my $command = MGAP::Command::UploadResult->create();

## Workaround for something in UR eating arguments to create()
$command->dev(1);
$command->seq_set_id(43);
$command->bio_seq_features([$feature]);
                                                 
isa_ok($command, 'MGAP::Command::UploadResult');

ok($command->execute());

my $trna = BAP::DB::tRNAGene->retrieve(gene_name => 'ESCCOLD8X_Contig766.1.t1');

isa_ok($trna, 'BAP::DB::tRNAGene');

ok(BAP::DB::DBI->dbi_rollback());

