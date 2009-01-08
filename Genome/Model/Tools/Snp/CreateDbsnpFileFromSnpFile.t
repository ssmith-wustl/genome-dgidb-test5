#!/usr/bin/env perl
use strict;
use warnings;

use above "Genome";
use FindBin qw($Bin);
use Test::More tests => 3; 
use Test::More; 
#plan skip_all => 'Does not pass. Do not know what we need to do to make it pass. Fix me.';

#gt snp create-dbsnp-file-from-snp-file --output-file create-dbsnp-file-from-snp-file.out --snp-file /gscmnt/sata146/info/medseq/dlarson/GBM_Genome_Model/tumor/2733662090.snps


my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Snp-CreateDbsnpFileFromSnpFile';
unless (-d $dir) {
    die "Failed to find test directory $dir!";
}

my $tmp = File::Temp::tempdir();

if (-e "$tmp/out.snps") {
    unlink "$dir/out.snps";
}
if (-e "$tmp/out.snps") {
    die qq{Failed to unlink "$dir/out.snps": $!};
}

my $result = Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile->execute(
    output_file => "$tmp/out.snps",
    snp_file => "$dir/in.snps", 
);
ok($result, "command succeeded");

ok((-e "$tmp/out.snps"), "generated results");

my $diff = `diff $dir/expected.snps $tmp/out.snps`;
ok($diff eq '', "no differences") 
    or do {
        my $f = __FILE__;
        $f =~ s/\//-/g;
        IO::File->new(">/tmp/$f.errors")->print($diff);
        diag("differences are in /tmp/$f.errors");
    };

