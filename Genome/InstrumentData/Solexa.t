#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

use above 'Genome';

BEGIN {
        use_ok('Genome::InstrumentData::Solexa');
}
my $pe1 = Genome::InstrumentData::Solexa->get(2776188659);
ok(!$pe1,'Paired End Read 1 not found for lane');
my $pe2 = Genome::InstrumentData::Solexa->get(2776188660);
isa_ok($pe2,'Genome::InstrumentData::Solexa');
is($pe2->is_paired_end,1,'Paired End status found for lane');
#is($pe2->calculate_alignment_estimated_kb_usage,4000000,'4GB disk needed for paired end instrument data');
is($pe2->calculate_alignment_estimated_kb_usage,2443215,'4GB disk needed for paired end instrument data');
my @fastq_files = $pe2->fastq_filenames;
is(scalar(@fastq_files),2,'got 2 fastq files for paired end instrument data');
# need to see if we can get the forward-only or reverse-only bases from the paird end inst data
is($pe2->total_bases_read('forward-only'),375277950, 'forward only total_bases_read on paired end instrument data');
is($pe2->total_bases_read('reverse-only'),375277950, 'reverse only total_bases_read on paired end instrument data');
is($pe2->total_bases_read('forward-only') + $pe2->total_bases_read('reverse-only'), $pe2->total_bases_read,
   'forward and reverse pairs add up to total bases');

exit;
