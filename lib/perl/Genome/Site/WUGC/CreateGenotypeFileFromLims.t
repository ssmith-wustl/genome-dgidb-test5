#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Site::WUGC::CreateGenotypeFileFromLims') or die;

done_testing();
exit;

###
# This test relies on real LIMS data and takes > 7 min to run. Leaving here if
#  real testing is needed
my $tmpdir = Genome::Sys->base_temp_directory;
ok(-d $tmpdir, 'tmp dir');
my $gf = Genome::Site::WUGC::CreateGenotypeFileFromLims->create(
    genotype_id => 2869429316,
    # 36
    #db_snp_version => 130, 
    #genotype_file => $tmpdir.'/human.36.genotype',
    # 37
    db_snp_version => 132,
    genotype_file => $tmpdir.'/human.37.genotype',
);
ok($gf, 'create');
$gf->dump_status_messages(1);
ok($gf->execute, 'execute');

done_testing();
exit;

