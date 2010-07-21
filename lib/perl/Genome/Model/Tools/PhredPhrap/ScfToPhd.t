#!/gsc/bin/perl

use strict;
use warnings;
use Test::More tests => 3;
use above 'Genome';

BEGIN {
        use_ok('Genome::Model::Tools::PhredPhrap::ScfToPhd');
}
my $path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-PhredPhrap'; #directory for sample data and output
my $static = "$path/ScfToPhd/_phd_output.static"; #static file for comparison to output
my %params = (
        phd_dir => "$path/phd_dir/",
        chromat_dir => "$path/chromat_dir/",
        scf_file => "$path/ScfToPhd/scf.txt",
        phd_file => "$path/ScfToPhd/phd_output.txt", 
        );

my $scf_to_phd = Genome::Model::Tools::PhredPhrap::ScfToPhd->create(%params);



isa_ok($scf_to_phd,'Genome::Model::Tools::PhredPhrap::ScfToPhd');

ok($scf_to_phd->execute,'execute ScfToPhd');

unlink $scf_to_phd->phd_file if ((-e $scf_to_phd->phd_file or 
                                 die("Output file was not created"))
                             and
                                 (-s $scf_to_phd->phd_file) == -s $static or 
                                 die("Generated file $scf_to_phd->phd_file does not match static file:$static"));
exit;
