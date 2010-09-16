#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;
require File::Compare;

use_ok ('Genome::Model::Tools::Assembly::CreateOutputFiles::ReadsUnplaced') or die;

#check data dir and input files for test
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly/CreateOutputFiles/ReadsUnplaced_v0';
ok(-d $data_dir, "Data dir exists");
my @data_files = qw/ GABJJ9O01.fasta.gz GABJJ9O01.fasta.qual.gz GABJJ9O02.fasta.gz reads.placed /;
foreach (@data_files) {
    ok(-s $data_dir."/edit_dir/$_", "$_ file exists in data dir");
}

#create temp directory
my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
ok(-d $temp_dir, "Temp test dir created");
my $temp_edit_dir = Genome::Utility::FileSystem->create_directory($temp_dir.'/edit_dir');
ok(-d $temp_edit_dir, "Temp test edit_dir created");

#copy data files;
foreach (@data_files) {
    ok(File::Copy::copy($data_dir."/edit_dir/$_", $temp_edit_dir), "Copied $_ file to temp dir");
    ok(-s $temp_edit_dir."/$_", "$_ file exists in temp edit_dir");
}

#create / execute tool
my $c = Genome::Model::Tools::Assembly::CreateOutputFiles::ReadsUnplaced->create(
    directory => $temp_dir,
    reads_placed_file => $temp_edit_dir.'/reads.placed',
    );
ok($c, "Created reads-unplaced");
ok($c->execute, "Executed reads-unplaced");

#compare output files
foreach ('reads.unplaced', 'reads.unplaced.fasta') {
    ok(-s $data_dir."/edit_dir/$_", "Data dir $_ file exists");
    ok(-s $temp_edit_dir."/$_", "Temp dir $_ file exists");
    ok(File::Compare::compare($data_dir."/edit_dir/$_", $temp_edit_dir."/$_") == 0, "$_ files match");
}

#<STDIN>;

done_testing();

exit;
