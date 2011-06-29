#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use above "Genome";
require File::Compare;

my $archos = `uname -a`;
unless ($archos =~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}

use_ok( 'Genome::Model::Tools::Newbler::ToPcapAce' ) or die;

my $version = 'v1';
my $test_suite_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Newbler/ToPcapAce-'.$version;
ok( -d $test_suite_dir, "Test suite dir exists" ) or die;

my $scaffolds_file = '454Scaffolds.txt';
my $ace_in = '454Contigs.ace.1';
my $ace_out = 'Pcap.454Contigs.ace';

my $temp_test_dir = Genome::Sys->create_temp_directory();
ok( -d $temp_test_dir, "Temp test dir created" ) or die;
mkdir $temp_test_dir.'/consed';
ok( -d $temp_test_dir.'/consed', "Made consed dir in temp dir" ) or die;
mkdir $temp_test_dir.'/consed/edit_dir';
ok( -d $temp_test_dir.'/consed/edit_dir', "Made edit_dir in temp dir" ) or die;

my $test_scaffold_file = $test_suite_dir.'/'.$scaffolds_file;
ok( -s $test_scaffold_file, "Test scaffolds file exists" ) or die;
symlink( $test_scaffold_file, $temp_test_dir.'/'.$scaffolds_file );
ok( -l $temp_test_dir.'/'.$scaffolds_file, "Linked $scaffolds_file file" ) or die;

my $test_newb_ace = $test_suite_dir.'/consed/edit_dir/'.$ace_in;
ok( -s $test_newb_ace, "Test newb ace file exists" ) or die;
symlink( $test_newb_ace, $temp_test_dir.'/consed/edit_dir/'.$ace_in );
ok( -l $temp_test_dir.'/consed/edit_dir/'.$ace_in, "Linked $ace_in file" ) or die;

my $create = Genome::Model::Tools::Newbler::ToPcapAce->create(
    assembly_directory => $temp_test_dir,
);
ok( $create, "Created tool" ) or die;
ok( $create->execute, "Successfully executed tool" ) or die;

ok( -s $temp_test_dir.'/consed/edit_dir/'.$ace_out, "Created pcap ace file" ) or die;
ok( -s $test_suite_dir.'/consed/edit_dir/'.$ace_out, "Test suite pcap ace file exists" ) or die;

ok( File::Compare::compare ($temp_test_dir.'/consed/edit_dir/'.$ace_out, $test_suite_dir.'/consed/edit_dir/'.$ace_out ) == 0, "Ace files match" );

#<STDIN>;

done_testing();

exit;
