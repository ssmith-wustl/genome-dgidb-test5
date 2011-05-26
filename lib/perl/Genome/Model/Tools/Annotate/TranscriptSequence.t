#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

require File::Compare;
require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::Annotate::TranscriptSequence') or die;

my $transcript = "NM_001024809";
my $test_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence";
ok (-d $test_dir, 'test dir exists');
my $example_output = "$test_dir/NM_001024809.compare.txt.new";
ok (-s "$test_dir/$transcript.compare.txt.new", 'example output exists');
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

my $AnnotateTranscriptSequence = Genome::Model::Tools::Annotate::TranscriptSequence->create(
    transcript => $transcript,
    output => "$tmpdir/$transcript",
    no_stdout => 1,
);
ok($AnnotateTranscriptSequence, 'create');
ok($AnnotateTranscriptSequence->execute, 'execute');
is(File::Compare::compare($example_output, "$tmpdir/$transcript.txt"), 0, 'Output file matches');

#print "$tmpdir\n";<STDIN>;
done_testing();
exit;
