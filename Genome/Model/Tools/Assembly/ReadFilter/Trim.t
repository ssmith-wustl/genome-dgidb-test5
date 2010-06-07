#!/gsc/bin/perl

use strict;
use warnings;

use File::Temp;
use above "Genome";
use Genome::Model::Tools::Assembly::ReadFilter::Trim;
use IO::File;
use Bio::SeqIO;
use Bio::Seq::Quality;

#use Test::More skip_all => "Does not play nice with the test harness";
use Test::More tests => 1;

my $trimmer = Genome::Model::Tools::Assembly::ReadFilter::Trim->create(trim_length => 10);
my $io = Bio::SeqIO->new(-file => "/gsc/var/cache/testsuite/data/Genome-Model/DeNovoAssembly/velvet_solexa_build/collated.fastq", -format => 'fastq');
my $ok = 1;
my $count = 0;
while ((my $fq = $io->next_seq) && ($count++<500)) {
    my $length = length($fq->seq);
    my $qlength = scalar @{$fq->qual};
    
    $fq = $trimmer->trim($fq);
    my $new_length = length($fq->seq);
    my $new_qlength = scalar @{$fq->qual};
    if($length != ($new_length+10)||$qlength != ($new_qlength+10))
    {
        $ok=0;
        last;
    }
}

ok($ok, "Reads trimmed successfully");
