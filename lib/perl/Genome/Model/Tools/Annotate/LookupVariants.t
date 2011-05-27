#!/usr/bin/env perl

use strict;
use warnings;
use File::Temp;
use above "Genome";
use Test::More tests => 12;

use_ok('Genome::Model::Tools::Annotate::LookupVariants');
my $variant_file = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-LookupVariants/snp.list.in";
ok (-e $variant_file);

my $known_out = "/gsc/var/cache/testsuite/running_testsuites/Genome-Model-Tools-Annotate-LookupVariants-known-only.out";
if ($known_out && -e $known_out) {`rm $known_out`;}
my $exp_known_out = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-LookupVariants/expected.known-only.out";
ok (-e $exp_known_out);

my $known = Genome::Model::Tools::Annotate::LookupVariants->create(report_mode => "known-only", variant_file => "$variant_file", output_file => "/gsc/var/cache/testsuite/running_testsuites/Genome-Model-Tools-Annotate-LookupVariants-known-only.out", filter_out_submitters => "SNP500CANCER,OMIMSNP,CANCER-GENOME,CGAP-GAI,LCEISEN,ICRCG", require_allele_match => 1);
ok ($known);

my $kv = $known->execute;

ok ($kv);
ok (-e $known_out);
my $knowndiff = `diff $exp_known_out $known_out`;
ok($knowndiff eq '', "known output as expected");


my $novel_out ="/gsc/var/cache/testsuite/running_testsuites/Genome-Model-Tools-Annotate-LookupVariants-novel-only.out";
if ($novel_out && -e $novel_out) {`rm $novel_out`;}
my $exp_novel_out = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-LookupVariants/expected.novel-only.out";
ok (-e $exp_novel_out);


my $novel = Genome::Model::Tools::Annotate::LookupVariants->create(report_mode => "novel-only", variant_file => "$variant_file", output_file => "/gsc/var/cache/testsuite/running_testsuites/Genome-Model-Tools-Annotate-LookupVariants-novel-only.out", filter_out_submitters => "SNP500CANCER,OMIMSNP,CANCER-GENOME,CGAP-GAI,LCEISEN,ICRCG", require_allele_match => 1);
ok ($novel);

my $nv = $novel->execute;
ok ($nv);
ok (-e $novel_out);
my $noveldiff = `diff $exp_novel_out $novel_out`;
ok($noveldiff eq '', "novel output as expected");
