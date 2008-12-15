#!/usr/bin/env perl
use strict;
use warnings;

use above "Genome";
use FindBin qw($Bin);
use Test::More skip_all => "slow until we switch to file-based DB";

#gt snp create-dbsnp-file-from-snp-file --output-file create-dbsnp-file-from-snp-file.out --snp-file /gscmnt/sata146/info/medseq/dlarson/GBM_Genome_Model/tumor/2733662090.snps

my $dir = $Bin . '/CreateDbsnpFileFromSnpFile.t.d';
unless (-d $dir) {
    die "Failed to find test directory $dir!";
}

if (-e "$dir/out.snps") {
    unlink "$dir/out.snps";
}
if (-e "$dir/out.snps") {
    die qq{Failed to unlink "$dir/out.snps": $!};
}

my $result = Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile->execute(
    output_file => "$dir/out.snps",
    snp_file => "$dir/in.snps", 
);
ok($result, "command succeeded");

ok((-e "$dir/out.snps"), "generated results");

my $diff = `diff $dir/expected.snps $dir/out.snps`;
ok($diff eq '', "no differences") 
    or do {
        IO::File->new(">$dir/errors")->print($diff);
        diag("differences are in $dir/errors");
    };

