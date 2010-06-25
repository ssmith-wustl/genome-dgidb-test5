#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;
require File::Compare;

my $module = 'Genome-Model-Tools-Assembly-Ace';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found test data dir");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
ok(-d $temp_dir, "Made temp directory at $temp_dir");

my @test_aces = qw/ test_asm1.ace test_asm2.ace test_asm3.ace /;

foreach (@test_aces) {
    ok(-s $data_dir."/$_", "Test ace file $_ exists");
    symlink($data_dir."/$_", $temp_dir."/$_");
    ok(-s $temp_dir."/$_", "Linked $_");
}

my $ace_list_fh = IO::File->new(">".$temp_dir.'/ace_list') ||
    die "Can not create file handle to write ace list\n";
$ace_list_fh->print(map {$_."\n"} @test_aces);
$ace_list_fh->close;

ok(-s $temp_dir.'/ace_list', "Created temp ace list");

done_testing();

exit;
