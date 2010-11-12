#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome";  # forces a 'use lib' when run directly from the cmdline
use Test::More tests => 10;
use FindBin qw($Bin);
use File::Path;
use File::Basename;

my $datadir = $Bin . '/BamBuster.t.d';


my $tmp_dir = Genome::Utility::FileSystem->base_temp_directory;
my $test_dir = $tmp_dir . "/test";
mkpath($test_dir);

my $cmd = Genome::Model::Tools::Picard::BamBuster->create(input=>$datadir . "/testrg.bam",
                                                          output_directory=>$test_dir,
                                                          use_version=>'1.31'); 

ok($cmd, "created cmd");
ok($cmd->execute);

ok(-d $test_dir . '/test_sample_name-lib1', 'got lib1 extracted');
ok(-d $test_dir . '/test_sample_name-lib2', 'got lib2 extracted');

for my $rg_id ('-123456','-123457','-123458') {
    my @files = glob($test_dir . "/*/$rg_id" ."*");

    ok (@files == 1, "found a broken rg path for $rg_id");
    
    my ($generated_file) = @files;

    my $generated_file_sam = "$tmp_dir/$rg_id.generated";
    my $expected_file_sam = "$tmp_dir/$rg_id.expected";

    Genome::Utility::FileSystem->shellcmd(cmd=>sprintf("samtools view -h -- %s > %s", $generated_file, $generated_file_sam));
    Genome::Utility::FileSystem->shellcmd(cmd=>sprintf("samtools view -h -r %s -- %s > %s",
                                                        $rg_id, 
                                                        "$datadir/testrg.bam",
                                                        $expected_file_sam));

    is(Genome::Utility::FileSystem->md5sum($generated_file_sam),
    Genome::Utility::FileSystem->md5sum($expected_file_sam), "sam content matches what is expected")
                                    
}

