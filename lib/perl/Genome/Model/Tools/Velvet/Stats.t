#!/gsc/bin/perl

use strict;
use warnings;

use Cwd;
use above "Genome";
use Test::More;

use_ok( 'Genome::Model::Tools::Velvet::Stats' ) or die;

my $data_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-Stats/Velvet_v3";
ok(-d $data_dir, "Found data directory: $data_dir") or die;

#create temp test dir
my $temp_dir = Genome::Sys->create_temp_directory();

#make edit_dir in temp_dir
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Made edit_dir in temp test_dir");

#link assembly dir files needed to run stats
my @files_to_link = qw/ velvet_asm.afg Sequences contigs.fa /;
foreach (@files_to_link) {
    ok(-s $data_dir."/$_", "Test data file $_ exists");
    symlink($data_dir."/$_", $temp_dir."/$_");
    ok(-s $temp_dir."/$_", "Linked file $_ in tmp test dir");
}

#link assembly/edit_dir files needed to run stats
@files_to_link = qw/ velvet_asm.ace test.fasta.gz test.fasta.qual.gz
                        contigs.bases contigs.quals reads.placed readinfo.txt /;
foreach my $file (@files_to_link) {
    ok(-s $data_dir."/edit_dir/$file", "Test data file $file file exists");
    symlink($data_dir."/edit_dir/$file", $temp_dir."/edit_dir/$file");
    ok(-s $temp_dir."/edit_dir/$file", "Linked file $file in tmp test dir"); 
}

#create stats
my $create = Genome::Model::Tools::Velvet::Stats->create(
    assembly_directory => $temp_dir,
    out_file => $temp_dir.'/edit_dir/stats.txt',
    no_print_to_screen => 0,
    );
ok( $create, "Created tool" );
ok( $create->execute, "Successfully created stats" );

#check for stats files
my $temp_stats = $temp_dir.'/edit_dir/stats.txt';
my $data_stats = $data_dir.'/edit_dir/stats.txt';

ok(-s $temp_stats, "Tmp test dir stats.txt file exists");
ok(-s $data_stats,, "Test data dir stats.txt file exists");

#compare files
my @diff = `sdiff -s $data_stats $temp_stats`;
is(scalar @diff, 0, "Stats files match") or diag(@diff);

done_testing();

exit;
 

