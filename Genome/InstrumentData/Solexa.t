#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 6;

use above 'Genome';

BEGIN {
        use_ok('Genome::InstrumentData::Solexa');
}
my $pe1 = Genome::InstrumentData::Solexa->get(2776188659);
ok(!$pe1,'Paired End Read 1 not found for lane');
my $pe2 = Genome::InstrumentData::Solexa->get(2776188660);
isa_ok($pe2,'Genome::InstrumentData::Solexa');
is($pe2->is_paired_end,2,'Paired End Read 2 found for lane');
is($pe2->calculate_alignment_estimated_kb_usage,2000000,'2GB disk needed for paired end instrument data');
my @fastq_files = $pe2->fastq_filenames;
is(scalar(@fastq_files),2,'got 2 fastq files for paired end instrument data');
exit;
