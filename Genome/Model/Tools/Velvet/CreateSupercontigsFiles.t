#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

use Genome::Model::Tools::Velvet::CreateSupercontigsFiles;
require File::Compare;

#TODO - data to Genome-Model-Tools-Assembly-CreateOutputFiles when done
my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles2';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();

#make edit_dir
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Made edit_dir in temp dir");

#link project dir files
ok(-s $data_dir.'/contigs.fa', "Data dir contigs.fa file exists"); 
symlink ($data_dir.'/contigs.fa', $temp_dir.'/contigs.fa');
ok(-s $temp_dir.'/contigs.fa', "Tmp dir contigs.fa file exists");

my $ec = system("chdir $temp_dir; gmt velvet create-supercontigs-files --contigs-fasta-file $data_dir/contigs.fa --directory $temp_dir");
ok($ec == 0, "Command ran successfully");

foreach ('supercontigs.fasta', 'supercontigs.agp') {
    ok(-s $data_dir."/edit_dir/$_", "Data dir $_ file exists");
    ok(-s $temp_dir."/edit_dir/$_", "Tmp dir $_ file got created");
    ok(File::Compare::compare($data_dir."/edit_dir/$_", $temp_dir."/edit_dir/$_") == 0, "$_ files match");
}

done_testing();

exit;
