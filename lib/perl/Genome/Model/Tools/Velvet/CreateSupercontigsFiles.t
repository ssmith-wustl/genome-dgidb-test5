#!/gsc/bin/perl

use strict;
use warnings;

require File::Compare;
use above "Genome";
use Test::More;

use_ok ( 'Genome::Model::Tools::Velvet::CreateSupercontigsFiles' );

my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles2';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";
ok(-d $data_dir, "Found data directory: $data_dir");

my $temp_dir = Genome::Sys->create_temp_directory();

#link project dir files
ok(-s $data_dir.'/contigs.fa', "Data dir contigs.fa file exists"); 
symlink ($data_dir.'/contigs.fa', $temp_dir.'/contigs.fa');
ok(-s $temp_dir.'/contigs.fa', "Tmp dir contigs.fa file exists");

#create / execute tool
my $create = Genome::Model::Tools::Velvet::CreateSupercontigsFiles->create (
    assembly_directory => $temp_dir,
    );
ok( $create, "Created tool");
ok( $create->execute, "Successfully executed tool");

foreach ('supercontigs.fasta', 'supercontigs.agp') {
    ok(-s $data_dir."/edit_dir/$_", "Data dir $_ file exists");
    ok(-s $temp_dir."/edit_dir/$_", "Tmp dir $_ file got created");
    ok(File::Compare::compare($data_dir."/edit_dir/$_", $temp_dir."/edit_dir/$_") == 0, "$_ files match");
}

done_testing();

exit;
