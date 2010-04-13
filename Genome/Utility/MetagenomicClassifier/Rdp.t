#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Bio::SeqIO;
use Test::More;

#this serves as the test case for all versions of Rdp - inheriting from Genome::Utility::MetagenomicClassifier::Rdp

use_ok('Genome::Utility::MetagenomicClassifier::Rdp::Version2x1');
use_ok('Genome::Utility::MetagenomicClassifier::Rdp::Version2x2');

my $display_id = 'S000002017 Pirellula staleyi';
my $seq_str = 'AATGAACGTTGGCGGCATGGATTAGGCATGCAAGTCGTGCGCGATATGTAGCAATACATGGAGAGCGGCGAAAGGGAGAGTAATACGTAGGAACCTACCTTCGGGTCTGGGATAGCGGCGGGAAACTGCCGGTAATACCAGATGATGTTTCCGAACCAAAGGTGTGATTCCGCCTGAAGAGGGGCCTACGTCGTATTAGCTAGTTGGTAGGGTAATGGCCTACCAAGnCAAAGATGCGTATGGGGTGTGAGAGCATGCCCCCACTCACTGGGACTGAGACACTGCCCAGACACCTACGGGTGGCTGCAGTCGAGAATCTTCGGCAATGGGCGAAAGCCTGACCGAGCGATGCCGCGTGCGGGATGAAGGCCTTCGGGTTGTAAACCGCTGTCGTAGGGGATGAAGTGCTAGGGGGTTCTCCCTCTAGTTTGACTGAACCTAGGAGGAAGGnCCGnCTAATCTCGTGCCAGCAnCCGCGGTAATACGAGAGGCCCAnACGTTATTCGGATTTACTGGGCTTAAAGAGTTCGTAGGCGGTCTTGTAAGTGGGGTGTGAAATCCCTCGGCTCAACCGAGGAACTGCGCTCCAnACTACAAGACTTGAGGGGGATAGAGGTAAGCGGAACTGATGGTGGAGCGGTGAAATGCGTTGATATCATCAGGAACACCGGAGGCGAAGGCGGCTTACTGGGTCCTTTCTGACGCTGAGGAACGAAAGCTAGGGGAGCAnACGGGATTAGATACCCCGGTAGTCCTAnCCGTAAACGATGAGCACTGGACCGGAGCTCTGCACAGGGTTTCGGTCGTAGCGAAAGTGTTAAGTGCTCCGCCTGGGGAGTATGGTCGCAAGGCTGAAACTCAAAGGAATTGACGGGGGCTCACACAAGCGGTGGAGGATGTGGCTTAATTCGAGGCTACGCGAAGAACCTTATCCTAGTCTTGACATGCTTAGGAATCTTCCTGAAAGGGAGGAGTGCTCGCAAGAGAGCCTnTGCACAGGTGCTGCATGGCTGTCGTCAGCTCGTGTCGTGAGATGTCGGGTTAAGTCCCTTAACGAGCGAAACCCTnGTCCTTAGTTACCAGCGCGTCATGGCGGGGACTCTAAGGAGACTGCCGGTGTTAAACCGGAGGAAGGTGGGGATGACGTCAAGTCCTCATGGCCTTTATGATTAGGGCTGCACACGTCCTACAATnGTGCACACAAAGCGACGCAAnCTCGTGAGAGCCAGCTAAGTTCGGATTGCAGGCTGCAACTCGCCTGCATGAAGCTGGAATCGCTAGTAATCGCGGGTCAGCATACCGCGGTGAATGTGTTCCTGAGCCTTGTACACACCGCCCGTCAAGCCACGAAAGTGGGGGGGACCCAACAGCGCTGCCGTAACCGCAAGGAACAAGGCGCCTAAGGTCAACTCCGTGATTGGGACTAAGTCGTAACAAGGTAGCCGTAGGGGAACCTGCGGCTGGATCACCTCCTT';

my $rev_str = scalar reverse $seq_str;
my $seq = Bio::Seq->new( 
    -display_id => $display_id,
    -seq => $seq_str,
);

my $rev_seq = $seq->revcom();

my $training_set = '';#'broad';#(4,6)

#list versions
my @versions = (Genome::Utility::MetagenomicClassifier::Rdp::Version2x1->new(training_set => $training_set),
                Genome::Utility::MetagenomicClassifier::Rdp::Version2x2->new(training_set => $training_set));

foreach my $classifier (@versions)
{
    my $version = $classifier->get_training_version;

    ok ($version ne '', 'Got training set version');
    ok($classifier, 'Created rdp classifier');

    my $classification = $classifier->classify($seq);
    ok($classification, 'got classification from classifier');
    isa_ok($classification, 'Genome::Utility::MetagenomicClassifier::SequenceClassification');
    my $taxon = $classification->get_taxon;
    do {
        ($taxon) = $taxon->each_Descendent;
    } until ($taxon->is_Leaf()); 
    ok($taxon->id eq 'Pirellula', 'found correct classification');

    my ($conf) = $taxon->get_tag_values('confidence');
    ok($conf == 1.0, 'found correct confidence value');

    my $is_reversed = $classifier->is_reversed($rev_seq);
    ok ($is_reversed, 'reverse correctly identified');
}

done_testing();
exit;

#$HeadURL$
#$Id$
