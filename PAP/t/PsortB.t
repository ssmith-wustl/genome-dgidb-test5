use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 355;

BEGIN {
    use_ok('PAP::Command');
    use_ok('PAP::Command::PsortB');
}

my $command = PAP::Command::PsortB->create(
                                           'fasta_file' => 'data/B_coprocola.chunk.fasta',
                                           'gram_stain' => 'negative',
                                          );
isa_ok($command, 'PAP::Command::PsortB');

ok($command->execute());

my $ref = $command->bio_seq_feature();

is(ref($ref), 'ARRAY');

foreach my $feature (@{$ref}) {

    isa_ok($feature, 'Bio::SeqFeature::Generic');
    
    ok($feature->has_tag('psort_localization'), 'has localization tag');
    ok($feature->has_tag('psort_score'), 'has score tag');

    my @localizations = $feature->get_tag_values('psort_localization');
    my @scores        = $feature->get_tag_values('psort_score');

    ok(@localizations == 1, 'has only one localization');
    ok(@scores == 1, 'has only one score');

    like($localizations[0], qr/\w+/, 'localization is numeric');
    like($scores[0], qr/\d+\.\d+/, 'score is floating point');
    
}
