#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 10;
$ENV{UR_DBI_NO_COMMIT} = 1;

my $m = Genome::Model->get(2771359026); 
ok($m, "got a model"); 

# we may build and build again, but just test this build...
# TODO: mock
#my $build_id = 96402993; This build does not exist anymore. 
my $build_id = 97848505;
my @completed = $m->completed_builds;
for my $b (@completed) {
    next if $b->id == $build_id;
    my $e = $b->build_event;
    $e->event_status('Running');    
    $e->date_completed(undef);
}

my $last_complete_build = $m->last_complete_build;
unless ($last_complete_build->id == $build_id) {
    die "Failed to force model " . $m->id . " to use build " . $build_id . " as its last complete build.  Got " . $last_complete_build->id;
}

my $refseq = 'all_sequences';

my @var = $m->_variant_list_files();
ok(scalar @var, "identified " . scalar @var . " snp files of $refseq");
ok(all_exist(@var),"the snp files exist") or diag('example path: ' .$var[0]);

@var = $m->_variant_detail_files();
ok(scalar @var, "identified " . scalar @var . " pileup files of $refseq");
ok(all_exist(@var),"the pileup files exist") or diag('example path: ' . $var[0]);

@var = $m->_variation_metrics_files();
ok(scalar @var, "identified " . scalar @var . " variation metrics files of $refseq");

SKIP: {
    skip 'We do not generate other_snp_related_metrics subdir right now', 1;
    ok(all_exist(@var),"the variation files exist");
}

$DB::single=1;
my $v = $m->variant_count();
is($v, 6631155, 'Got expected variant count');

my $f;

my $data_directory = $m->complete_build_directory;
#my $expected = '/gscmnt/sata821/info/model_data/2771359026/build96402993';
my $expected ='/gscmnt/sata905/info/model_data/2771359026/build97848505';
is($data_directory, $expected, "resolved data directory");  # FIX WHEN WE SWITCH MODELS

#$f = $m->resolve_accumulated_alignments_filename();
#is($f, 'FIXME', "found accumulated alignments file name"); #FIXME WHEN WE SWITCH MODELS

$f = $m->accumulated_alignments_directory();
is($f, "$data_directory/alignments", "found alignments directory");

#@f = $m->maplist_file_paths();
#is(scalar(@f), 'FIXME', "found maplist file paths"); #FIXME WHEN WE SWITCH MODELS

sub all_exist {
    return (!(grep{ ! -e $_ } @_) ? 1 : 0);
}

