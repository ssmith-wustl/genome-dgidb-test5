#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}

use above 'Genome';

use_ok('Genome::Model::Tools::Vcf::Convert::Indel::Bed');

=cut
my $test_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Vcf-Convert-Indel-Bed";
# V2 corrects the BQ value to subtract 33 from the ascii value
# V3 - various corrections
# V4 - remove VT INFO field in header
# V5 - add source in header
# V6 - Correct the AD and BQ fields number attribute
my $expected_base = "expected.v1";
my $expected_dir = "$test_dir/$expected_base";
my $expected_file = "$expected_dir/output.vcf";

#my $output_file = Genome::Sys->create_temp_file_path;
my $output_file = "temp";
#my $input_file = "$test_dir/snvs.hq";
my $input_file = "/gscuser/aregier/test/annotate/sample2876425243/indels.hq.novel.tier1.v2.bed";

my $command = Genome::Model::Tools::Vcf::Convert::Indel::Bed->create( input_file => $input_file, 
                                                                       output_file  => $output_file,
                                                                       aligned_reads_sample => "TEST",
                                                                       reference_sequence_build_id => 106942997);

ok($command, 'Command created');
my $rv = $command->execute;
ok($rv, 'Command completed successfully');
ok(-s $output_file, "output file created");

# The files will have a timestamp that will differ. Ignore this but check the rest.
my $expected = `cat $expected_file | grep -v fileDate`;
my $output = `zcat $output_file | grep -v fileDate`;
my $diff = Genome::Sys->diff_text_vs_text($output, $expected);
ok(!$diff, 'output matched expected result')
    or diag("diff results:\n" . $diff);
=cut
done_testing();
