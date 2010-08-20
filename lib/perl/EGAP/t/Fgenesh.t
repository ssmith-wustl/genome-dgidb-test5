use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use File::Basename;
use Test::More tests => 858;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::GenePredictor::Fgenesh');
}

##FIXME:  Note that the EGAP::Job will fail in a bizarre fashion if the parameter file arg is garbage - sanity check should be added
my $command = EGAP::Command::GenePredictor::Fgenesh->create(
    fasta_file => File::Basename::dirname(__FILE__).'/data/Contig0a.masked.fasta',
    model_file => '/gsc/pkg/bio/softberry/installed/sprog/C_elegans',
);

isa_ok($command, 'EGAP::Command::GenePredictor');
isa_ok($command, 'EGAP::Command::GenePredictor::Fgenesh');

ok($command->execute());

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::Tools::Prediction::Gene');
    ok(defined($feature->seq_id()));
    is($feature->seq_id(), 'TRISPI_Contig0.a');
}
