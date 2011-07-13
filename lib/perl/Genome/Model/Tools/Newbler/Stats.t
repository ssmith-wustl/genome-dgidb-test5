#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use above "Genome";
use File::Copy;
require File::Compare;

use_ok( 'Genome::Model::Tools::Newbler::Stats' ) or die;

my $version = 'v3';
my $test_suite = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Newbler/Stats-'.$version;
ok( -d $test_suite, "Test suite dir exists" ) or die;

my $temp_dir = Genome::Sys->create_temp_directory();
ok( -d $temp_dir, "Created temp directory" );
Genome::Sys->create_directory( $temp_dir.'/consed' );
Genome::Sys->create_directory( $temp_dir.'/consed/edit_dir' );
ok( -d $temp_dir.'/consed/edit_dir', "Temp dir edit_dir created" );

my @files_to_copy = (
'consed/edit_dir/contigs.bases',
'consed/edit_dir/contigs.quals',
'consed/edit_dir/readinfo.txt',
'2869511846-input.fastq',
'454NewblerMetrics.txt',
'454ReadStatus.txt'
);

for my $file ( @files_to_copy ) {
    ok( -s "$test_suite/$file", "Test suite $file file exists" );
    File::Copy::copy( "$test_suite/$file", "$temp_dir/$file" );
    ok( -s "$temp_dir/$file", "Copied $file to temp dir" );
}

my $create = Genome::Model::Tools::Newbler::Stats->create(
    assembly_directory => $temp_dir,
);
ok( $create, "Created tool" );
ok( $create->execute, "Successfully executed tool" );

my $stats_file = 'consed/edit_dir/stats.txt';
ok( -s "$test_suite/$stats_file", "Example stats file exists" );
ok( -s "$temp_dir/$stats_file", "Test stats file exists" );
ok( File::Compare::compare( "$temp_dir/$stats_file", "$test_suite/$stats_file" ) == 0, "Stats files match" );

#<STDIN>;

done_testing();

exit;
