use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use Data::Dumper;
use File::Temp;
use Storable qw(nstore retrieve);

$Storable::forgive_me = 1;
$Storable::Deparse    = 1;

my $command = EGAP::Command::GenePredictor::SNAP->create(
                                                         'fasta_file' => 'data/SCTG6.a.dna.masked.fasta',
                                                         'hmm_file'   => '/gsc/pkg/bio/snap/installed/HMM/C.elegans.hmm' 
                                                        );

$command->execute();

my @features = @{$command->bio_seq_feature()};

my $ref = retrieve($ARGV[0]);

push @{$ref}, @features;

nstore $ref, $ARGV[1];

