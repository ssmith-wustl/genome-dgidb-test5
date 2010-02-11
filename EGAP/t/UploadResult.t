use strict;
use warnings;

use above 'EGAP';

use Bio::SeqIO;
use Bio::SeqFeature::Generic;
use Bio::Tools::Prediction::Gene;
use Bio::Tools::Prediction::Exon;

use Test::More tests => 4;
use Storable;

$Storable::Deparse    = 1;
$Storable::forgive_me = 1;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::UploadResult');
}

my $seqio = Bio::SeqIO->new(-file => 'data/SCTG6.a.dna.masked.fasta', -format => 'Fasta');

my $seq = $seqio->next_seq();

my $ab_initio_features = Storable::retrieve('bsf-snap-fgenesh.storable');
my $rna_features       = Storable::retrieve('bsf-trnascan-rfam_scan.storable');

my $features = [ @{$ab_initio_features}, @{$rna_features} ];

my $organism = EGAP::Organism->create(
                                      organism_name => 'bogus organism for unit testing',
                                     );
                                     
my $sequence_set = EGAP::SequenceSet->create(
                                             sequence_set_name => 'bogus sequence set for unit testing',
                                             organism          => $organism,
                                             software_version  => 'unknown',
                                             data_version      => 'unknown',
                                            );
my $sequence = EGAP::Sequence->create(
                                      sequence_name => 'TRISPI_Contig6.a',
                                      sequence_set_id => $sequence_set->sequence_set_id(),
                                      sequence_string => $seq->seq(),
                                     );
                                            
my $command = EGAP::Command::UploadResult->create(
                                                  seq_set_id         => $sequence_set->sequence_set_id,
                                                  'bio_seq_features' => $features,
                                                 );

isa_ok($command, 'EGAP::Command::UploadResult');

ok($command->execute());

UR::Context->rollback();
