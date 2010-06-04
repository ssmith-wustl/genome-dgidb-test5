#!/gsc/bin/perl

use strict;
use warnings;
use Test::More tests => 12;
use above "Genome";
use Genome::Model::Tools::Bmr::WtfToBitmask;
use Genome::Utility::FileSystem;

#test by providing input files?
my $small_genome = <<"GENOME";
5	75
10	100
3	25
GENOME

my $coverage_test = <<"COVERAGE";
fixedStep chrom=10 start=56 step=1
1
0
1
0
1
0
1
1
fixedStep chrom=5 start=1 step=10 span=5
1
1
0
0
fixedStep chrom=3 start=21 step=1
0
1
0
1
0
COVERAGE

#first check that the parsing works ok
my ($temp_fh,$temporary_genome_definition_file) = Genome::Utility::FileSystem->create_temp_file();
print $temp_fh $small_genome;
$temp_fh->close;

my ($cvg_fh, $temporary_coverage_file) = Genome::Utility::FileSystem->create_temp_file();
print $cvg_fh $coverage_test;
$cvg_fh->close;

my $obj = Genome::Model::Tools::Bmr::WtfToBitmask->execute(wtf_file => $temporary_coverage_file, reference_index => $temporary_genome_definition_file);

#This test is undoubtedly terrible
ok(defined $obj->bitmask, "Returned a defined bitmask hashref");
ok(exists($obj->bitmask->{10}), "Chromosome 10 in test file exists in bitmask");
ok($obj->bitmask->{10}->Norm == 5, "Proper number of bits set on chromosome 10");
my $failed = 0;
for my $index (56,58,60,62,63) { 

    unless($obj->bitmask->{10}->bit_test($index)) {
        $failed = $index;
        last;
    }
}
if($failed) {
    fail("Check of chromosome 10 bits failed on bit $failed");
}
else {
    pass("Check of chromosome 10 bits");
}

#This test is undoubtedly terrible too
ok(exists($obj->bitmask->{5}), "Chromosome 5 in test file exists in bitmask");
ok($obj->bitmask->{5}->Norm == 10, "Proper number of bits set on chromosome 5");
$failed = 0;
for my $index (1..5,11..15,) { 

    unless($obj->bitmask->{5}->bit_test($index)) {
        $failed = $index;
        last;
    }
}
if($failed) {
    fail("Check of chromosome 5 bits failed on bit $failed");
}
else {
    pass("Check of chromosome 5 bits");
}

#test integrity
my $temp_file = Genome::Utility::FileSystem->create_temp_file_path;
ok($obj->write_genome_bitmask($temp_file, $obj->bitmask),"Able to write out genome file");
my $genome_ref = $obj->read_genome_bitmask($temp_file);
ok(defined $genome_ref, "Able to read in genome file");

#now diff them somehow. Expect 3 tests
foreach my $chr (sort keys %$genome_ref) {
    ok($genome_ref->{$chr}->equal($obj->bitmask->{$chr}), "Chromosome $chr matches after loading from disk");
}

