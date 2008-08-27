use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use Cwd;
use File::Temp;
use Test::More tests => 287;

BEGIN {
    use_ok('PAP::Command');
    use_ok('PAP::Command::KEGGScan');
}

my $command = PAP::Command::KEGGScan->create('fasta_file' => 'data/B_coprocola.chunk.fasta');
isa_ok($command, 'PAP::Command::KEGGScan');

ok($command->execute());

my $ref = $command->bio_seq_feature();

is(ref($ref), 'ARRAY');

foreach my $feature (@{$ref}) {

    isa_ok($feature, 'Bio::SeqFeature::Generic');
     
    ok($feature->has_tag('kegg_evalue'));
    ok($feature->has_tag('kegg_description'));

    my $annotation_collection = $feature->annotation();

    isa_ok($annotation_collection, 'Bio::Annotation::Collection');

    foreach my $annotation ($annotation_collection->get_Annotations()) {

        isa_ok($annotation, 'Bio::Annotation::DBLink');
    
    }
    
}
