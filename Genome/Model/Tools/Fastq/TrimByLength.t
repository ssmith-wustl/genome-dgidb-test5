#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Bio::SeqIO;
use Test::More;

# use
use_ok('Genome::Model::Tools::Fastq::TrimByLength') or die;
use_ok('Genome::Model::Tools::Fastq::Reader') or die;

# create failures
ok(!Genome::Model::Tools::Assembly::ReadFilter::Trim->create(), 'Create w/o trim length');
ok(!Genome::Model::Tools::Assembly::ReadFilter::Trim->create(trim_length => 'all'), 'Create w/ trim length => all');
ok(!Genome::Model::Tools::Assembly::ReadFilter::Trim->create(trim_length => 0), 'Create w/ trim length => 0');

# valid create and execution
my $fastq_file = '/gsc/var/cache/testsuite/data/Genome-Model/DeNovoAssembly/velvet_solexa_build/collated.fastq';

#my $io = Bio::SeqIO->new(-file => $fastq_file, -format => 'fastq');

my $trimmer = Genome::Model::Tools::Fastq::TrimByLength->create(trim_length => 10);
my $reader  = Genome::Model::Tools::Fastq::Reader->create(fastq_file => $fastq_file);

my $ok = 1;
my $count = 0;
while ((my $fq = $reader->next) && ($count++<500)) {
    my $length  = length($fq->{seq});
    my $qlength = length($fq->{qual});
    
    $fq = $trimmer->trim($fq);
    my $new_length = length($fq->{seq});
    my $new_qlength = length ($fq->{qual});
    if($length != ($new_length+10)||$qlength != ($new_qlength+10)) {
        $ok=0;
        last;
    }
}

ok($ok, "Reads trimmed successfully");

done_testing();
exit;

#HeadURL$
#$Id$
