use strict;
use warnings;

use above 'GAP';

use Bio::Seq;
use Bio::SeqIO;

use Data::Dumper;
use File::Temp;
use Storable qw(nstore retrieve);

use GAP::Command;
use GAP::Command::GenePredictor::tRNAscan;

$Storable::forgive_me = 1;
$Storable::Deparse    = 1;

my $command = GAP::Command::GenePredictor::tRNAscan->create(
                                                            'fasta_file' => 'data/SCTG6.a.dna.masked.fasta',
                                                            'domain'     => 'eukaryota',
                                                           );

$command->execute();

my @features = @{$command->bio_seq_feature()};

my $ref = retrieve($ARGV[0]);

push @{$ref}, @features;

nstore $ref, $ARGV[1];
