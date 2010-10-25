#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";  # forces a 'use lib' when run directly from the cmdline
use Test::More tests => 7;
use FindBin qw($Bin);
use File::Temp;

my $datadir = $Bin . '/RemoveNPairwise.t.d';
 
my $fwd_fastq = $datadir . '/fwd.txt';
my $rev_fastq = $datadir . '/rev.txt';

my $dir = File::Temp::tempdir(CLEANUP => 1);
$dir or die "Failed to create temp directory!";

my $cmd = Genome::Model::Tools::Fastq::RemoveNPairwise->create(forward_fastq=>$fwd_fastq,
                                                                reverse_fastq=>$rev_fastq,
                                                                forward_n_removed_file=>$dir . "/nf.txt",
                                                                reverse_n_removed_file=>$dir . "/nr.txt",
                                                                singleton_n_removed_file=>$dir . "/ns.txt",
                                                                cutoff=>5);

ok($cmd, "successfully created pairwise n remove cmd");
ok($cmd->execute, "successfully executed pairwise n remove cmd");
is($cmd->pairs_passed, 1, "correct number of pairs passed");
is($cmd->pairs_passed, 1, "correct number of singletons passed");
is(Genome::Utility::FileSystem->md5sum($dir . "/nf.txt"),
   Genome::Utility::FileSystem->md5sum($datadir . "/expected_fwd.txt"),
   'fwd output matches what was expected');
is(Genome::Utility::FileSystem->md5sum($dir . "/nr.txt"),
   Genome::Utility::FileSystem->md5sum($datadir . "/expected_rev.txt"),
   'rev output matches what was expected');
is(Genome::Utility::FileSystem->md5sum($dir . "/ns.txt"),
   Genome::Utility::FileSystem->md5sum($datadir . "/expected_singleton.txt"),
   'singleton output matches what was expected');
