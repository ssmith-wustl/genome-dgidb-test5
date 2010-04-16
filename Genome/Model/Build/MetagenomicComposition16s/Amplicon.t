#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

require Bio::Seq::Quality;
use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Model::Build::MetagenomicComposition16s::Amplicon');

my $bioseq= Bio::Seq->new(
    '-id' => 'HMPB-aad13e12',
    '-seq' => 'ATTACCGCGGCTGCTGGCACGTAGCTAGCCGTGGCTTTCTATTCCGGTACCGTCAAATCCTCGCACTATTCGCACAAGAACCATTCGTCCCGATTAACAGAGCTTTACAACCCGAAGGCCGTCATCACTCACGCGGCGTTGCTCCGTCAGACTTTCGTCCATTGCGGAAGATTCCCCACTGCTGCCTCCCGTAGGAGTCTGGGCCGTGTCTCAGTCCCAATGTGGCCGTTCATCCTCTCAGACCGGCTACTGATCATCGCCTTGGTGGGCCGTTACCCCTCCAACTAGCTAATCAGACGCAATCCCCTCCTTCAGTGATAGCTTATAAATAGAGGCCACCTTTCATCCAGTCTCGATGCCGAGATTGGGATCGTATGCGGTATTAGCAGTCGTTTCCAACTGTTGTCCCCCTCTGAAGGGCAGGTTGATTACGCGTTACTCACCCGTTCGCCACTAAGATTGAAAGAAGCAAGCTTCCATCGCTCTTCGTTCGACTTGCATGTGTTAAGCACGCCG',
);
ok($bioseq, 'created bioseq');

my %valid_params = (
    name => $bioseq->id,
    reads => [qw/ 
    HMPB-aad13e12.b1 HMPB-aad13e12.b2 HMPB-aad13e12.b3 
    HMPB-aad13e12.b4 HMPB-aad13e12.g1 HMPB-aad13e12.g2 
    /],
    reads_processed => [qw/ 
    HMPB-aad13e12.b1 HMPB-aad13e12.b2 HMPB-aad13e12.b3 
    /],
    bioseq => $bioseq,
    classification_file => '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSanger/build/classification/HMPB-aad13e12.classification.stor',
);
my $amplicon = Genome::Model::Build::MetagenomicComposition16s::Amplicon->create(
    %valid_params
);
ok($amplicon, 'Created amplicon');
is($amplicon->name, $bioseq->id, 'name');
ok($amplicon->oriented_bioseq, 'oriented bioseq');
ok($amplicon->classification, 'classification');
is($amplicon->reads_count, 6, 'reads count');
is($amplicon->reads_processed_count, 3, 'processed reads count');

done_testing();
exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2010 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$

