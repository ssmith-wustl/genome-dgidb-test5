#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Model::Build::MetagenomicComposition16s::Amplicon') or die;

my $seq= {
    id => 'HMPB-aad13e12',
    seq => 'ATTACCGCGGCTGCTGGCACGTAGCTAGCCGTGGCTTTCTATTCCGGTACCGTCAAATCCTCGCACTATTCGCACAAGAACCATTCGTCCCGATTAACAGAGCTTTACAACCCGAAGGCCGTCATCACTCACGCGGCGTTGCTCCGTCAGACTTTCGTCCATTGCGGAAGATTCCCCACTGCTGCCTCCCGTAGGAGTCTGGGCCGTGTCTCAGTCCCAATGTGGCCGTTCATCCTCTCAGACCGGCTACTGATCATCGCCTTGGTGGGCCGTTACCCCTCCAACTAGCTAATCAGACGCAATCCCCTCCTTCAGTGATAGCTTATAAATAGAGGCCACCTTTCATCCAGTCTCGATGCCGAGATTGGGATCGTATGCGGTATTAGCAGTCGTTTCCAACTGTTGTCCCCCTCTGAAGGGCAGGTTGATTACGCGTTACTCACCCGTTCGCCACTAAGATTGAAAGAAGCAAGCTTCCATCGCTCTTCGTTCGACTTGCATGTGTTAAGCACGCCG',
};
ok($seq, 'created seq');

my %valid_params = (
    name => $seq->{id},
    reads => [qw/ 
    HMPB-aad13e12.b1 HMPB-aad13e12.b2 HMPB-aad13e12.b3 
    HMPB-aad13e12.b4 HMPB-aad13e12.g1 HMPB-aad13e12.g2 
    /],
    reads_processed => [qw/ 
    HMPB-aad13e12.b1 HMPB-aad13e12.b2 HMPB-aad13e12.b3 
    /],
    seq => $seq,
    classification_file => '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSanger/build/classification/HMPB-aad13e12.classification.stor',
);
my $amplicon = Genome::Model::Build::MetagenomicComposition16s::Amplicon->create(
    %valid_params
);
ok($amplicon, 'Created amplicon');
is($amplicon->name, $seq->{id}, 'name');
ok($amplicon->oriented_seq, 'oriented seq');
ok($amplicon->classification, 'classification');
is($amplicon->reads_count, 6, 'reads count');
is($amplicon->reads_processed_count, 3, 'processed reads count');

done_testing();
exit;

