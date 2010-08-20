#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

my $archos = `uname -a`;
unless ($archos =~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}

#check for test data files
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Soap/DeNovo/Assemble/data_dir';
ok(-d $data_dir, "Data dir exists");

my @data_files = qw/ config.txt fasta.fragment1.1 fasta.fragment1.2 fasta.fragment2.1 fasta.fragment2.2
                     fasta.pair1_a fasta.pair1_b fasta.pair2_a fasta.pair2_b /;

foreach (@data_files) {
    ok(-s $data_dir."/$_", "Data dir $_ file exists");
}

#make temp test dir
my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
ok(-d $temp_dir, "Temp test dir created");

#run soap denovo
my $create = Genome::Model::Tools::Soap::DeNovoAssemble->create(
    version => 1.04,
    config_file => "$data_dir/config.txt",
    kmer_size => 31,
    resolve_repeats => 1,
    kmer_frequency_cutoff => 1,
    cpus => 8,
    output_and_prefix => "$temp_dir/TEST",
    );

ok( $create, "Created gmt soap de-novo assemble");
ok(($create->execute) == 1, "Command ran successfully");

#compare output files
my $data_run_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Soap/DeNovo/Assemble/run_dir';
ok(-d $data_run_dir, "Data run dir exists");

my @diffs = `diff -r --brief $temp_dir $data_run_dir`;
is (scalar (@diffs), 0, "Run outputs match");

#<STDIN>;

done_testing();

exit;
