use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 399;

BEGIN {
    use_ok('PAP::Command');
    use_ok('PAP::Command::BlastP');
}

my $command = PAP::Command::BlastP->create('fasta_file' => 'data/B_coprocola.chunk.fasta');
isa_ok($command, 'PAP::Command::BlastP');

ok($command->execute());

my $ref = $command->bio_seq_feature();

is(ref($ref), 'ARRAY');

foreach my $feature (@{$ref}) {

    isa_ok($feature, 'Bio::SeqFeature::Generic');

    my $annotation_collection = $feature->annotation();

    isa_ok($annotation_collection, 'Bio::Annotation::Collection');

    my ($annotation) = $annotation_collection->get_Annotations();

    if (defined($annotation)) {
    
        isa_ok($annotation, 'Bio::Annotation::DBLink');
        is($annotation->database(), 'GenBank');
        like($annotation->primary_id(), qr/^\w+$/);

        ok($feature->has_tag('blastp_bit_score'));
        ok($feature->has_tag('blastp_evalue'));
        ok($feature->has_tag('blastp_percent_identical'));
        ok($feature->has_tag('blastp_query_start'));
        ok($feature->has_tag('blastp_query_end'));
        ok($feature->has_tag('blastp_subject_start'));
        ok($feature->has_tag('blastp_subject_end'));
        ok($feature->has_tag('blastp_hit_name'));

    }
    
    ok($feature->has_tag('blastp_category'));

}

my $blast_report_fh = $command->blast_report();

isa_ok($blast_report_fh, 'File::Temp');
ok($blast_report_fh->opened());

