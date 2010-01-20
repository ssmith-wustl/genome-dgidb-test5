use strict;
use warnings;

use above 'EGAP';

use Bio::SeqFeature::Generic;

use Test::More tests => 6;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::UploadResult');
}

my $feature = Bio::SeqFeature::Generic->new(
                                            -seq_id     => 'ESCCOLD8X_Contig766.1',
                                            -start      => 2112,
                                            -end        => 2191,
                                            -strand     => 1,
                                            -source_tag => 'tRNAscan-SE',
                                            -tag        => { 'Codon' => 'TAG', 'AminoAcid' => 'Leu' },
                                           );
              
my $command = EGAP::Command::UploadResult->create(
                                                  'seq_set_id' => 43,
                                                  'bio_seq_features' => [ [ $feature ] ],
                                                 );

isa_ok($command, 'EGAP::Command::UploadResult');

ok($command->execute());

my $trna = EGAP::tRNAGene->get(gene_name => 'ESCCOLD8X_Contig766.1.t1');

isa_ok($trna, 'EGAP::tRNAGene');

ok(UR::Context->rollback());

