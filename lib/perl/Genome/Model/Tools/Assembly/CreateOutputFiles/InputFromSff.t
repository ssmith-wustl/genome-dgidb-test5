#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

my $archos = `uname -a`;
unless ($archos =~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}

use_ok ('Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromSff') or die;

#check test dir/files
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly/CreateOutputFiles/InputFromSff_v0';
ok (-d $data_dir, "Data dir exists");
ok (-s $data_dir.'/sff/GABJJ9O01.sff', "Test sff file exists");

#create temp test dir
my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
my $temp_sff_dir = Genome::Utility::FileSystem->create_directory($temp_dir.'/sff');
ok (-d $temp_dir, "Created temp test dir");
ok (-d $temp_dir.'/sff', "Created temp test sff dir");

#print $temp_dir."\n";

#copy data over
ok (File::Copy::copy($data_dir.'/sff/GABJJ9O01.sff', $temp_dir.'/sff'), "Copied data file to temp dir");

#create/execute tool
my $create = Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromSff->create(
    directory => $temp_dir,
    );
ok ($create, "Created input-from-sff tool");
ok ($create->execute, "Executed input-from-sff tool");

#compare output files
foreach ('GABJJ9O01.fasta.gz', 'GABJJ9O01.fasta.gz') {
    my $data_file = $data_dir."/edit_dir/$_";
    my $temp_file = $temp_dir."/edit_dir/$_";
    ok (-s $data_file, "Data dir $_ file exists");
    ok (-s $temp_file, "Temp dir $_ file exists");
    my @diff = `zdiff $data_file $temp_file`;
    is (scalar @diff, 0, "Data and temp $_ files match");
}

#<STDIN>;

done_testing();

exit;
