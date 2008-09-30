use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use Cwd;
use File::Temp;
use Test::More tests => 193;

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

    my @annotations = $annotation_collection->get_Annotations();
    my @dblinks     = grep { $_->isa('Bio::Annotation::DBLink') } @annotations;
    
    my ($gene_dblink)      = grep { $_->primary_id() =~ /^\w{3}\:\w+$/ } @dblinks;
    my ($orthology_dblink) = grep { $_->primary_id() =~ /^K\d+$/       } @dblinks;
  
}
