use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use Data::Dumper;
use File::Temp;

use GAP::Command;
use GAP::Command::GenePredictor::RNAmmer;

my $command = GAP::Command::GenePredictor::RNAmmer->create(
                                                           'fasta_file' => 'data/SCTG6.a.dna.masked.fasta',
                                                           'domain'     => 'eukaryota',
                                                          );

$command->execute();

my @features = @{$command->bio_seq_feature()};

my $ref = retrieve($ARGV[0]);

push @{$ref}, @features;

nstore $ref, $ARGV[1];

