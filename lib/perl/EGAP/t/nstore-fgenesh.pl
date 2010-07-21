use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use Data::Dumper;
use File::Temp;
use Storable qw(nstore retrieve);

$Storable::forgive_me = 1;
$storable::Deparse    = 1;

##FIXME:  Note that the EGAP::Job will fail in a bizarre fashion if the parameter file arg is garbage - sanity check should be added
my $command = EGAP::Command::GenePredictor::Fgenesh->create(
                                                            'fasta_file'     => 'data/SCTG6.a.dna.masked.fasta',
                                                            'parameter_file' => '/gsc/pkg/bio/softberry/installed/sprog/C_elegans',
                                                            );

$command->execute();

my @features = @{$command->bio_seq_feature()};

my $ref = retrieve($ARGV[0]);

push @{$ref}, @features;

nstore $ref, $ARGV[1];

