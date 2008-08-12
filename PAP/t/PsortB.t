use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 55;

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

    my $ac = $feature->annotation();

    foreach my $annotation ($ac->get_Annotations()) {
        
        isa_ok($annotation, 'Bio::Annotation::SimpleValue');
    
    }

}
