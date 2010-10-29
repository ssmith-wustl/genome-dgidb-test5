#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
require File::Compare;

#check test suite dir/files
my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-SplitScaffold';
ok ( -d $test_dir, "Test suite dir exists") or die;
foreach (qw/ merge.ace split_out.ace /) {
    ok (-s $test_dir."/$_", "Test suite $_ file exists");
}

#create temp dir
my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
ok (-d $temp_dir, "Test test directory created") or die;

#create/run tool
my $create = Genome::Model::Tools::Assembly::SplitScaffold->create(
    ace_file => $test_dir.'/merge.ace',
    split_contig => 'Contig60.6',
    out_file_name => $temp_dir.'/split_out.ace',
    );
ok ($create, "Created split-scaffold tool") or die;
ok ($create->execute, "Successfully executed split-scaffold tool") or die;

#compare output files
ok (File::Compare::compare( $test_dir.'/split_out.ace', $temp_dir.'/split_out.ace') == 0, "Test output files match");

done_testing();

exit;
