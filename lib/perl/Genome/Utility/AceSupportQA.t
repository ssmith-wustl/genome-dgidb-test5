#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 16;

use_ok('Genome::Utility::AceSupportQA');

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Utility-AceSupportQA';

# Sample ace files to check. All should succeed the checker except 030 should fail
my @assemblies = (
                 'TCGA_Production-0005156_051-Ensembl-46_36h',
                 'TCGA_Production-0007157_030-Ensembl-46_36h',
		 '10_126008345_126010576'
);

for my $assembly (@assemblies) {

    my $ace_checker;
    if ($assembly =~ /TCGA_Production/) {
	$ace_checker = Genome::Utility::AceSupportQA->create(ref_check => 1);
    } else {
	$ace_checker = Genome::Utility::AceSupportQA->create();
    }
    ok($ace_checker, "created ace checker");
    isa_ok($ace_checker, "Genome::Utility::AceSupportQA");

    my $full_path = "$test_dir/$assembly/edit_dir/$assembly.ace";
    
    ok(-s $full_path, "Ace file test data exists");

    ok($ace_checker->ace_support_qa($full_path), "Ace file in assembly $assembly passes the ace checker");
    
    # Expect 030 to have more than one contig, rest to be ok
    if ($assembly eq 'TCGA_Production-0007157_030-Ensembl-46_36h') {
        ok($ace_checker->contig_count != 1, "More than one contig found as expected");
    } else {
        ok($ace_checker->contig_count == 1, "Exactly one contig found as expected");
    }
}
