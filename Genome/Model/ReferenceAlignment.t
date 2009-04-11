#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 14;
$ENV{UR_DBI_NO_COMMIT} = 1;

my $m = Genome::Model->get(2771359026); 
ok($m, "got a model"); 

# we may build and build again, but just test this build...
# TODO: mock
my $build_id = 96402993; 
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

my @f = $m->_consensus_files('X');
ok(scalar(@f), "identified " . scalar(@f) . " consensus file by refseq");

    my @f2 = $m->assembly_file_for_refseq('X');
    is("@f2","@f","old consensus method matches new with a refseq");

@f = $m->_consensus_files();
ok(scalar(@f), "identified " . scalar(@f) . " consensus files w/o refseq filter");
ok(all_exist(@f),"the consensus files exist")
    or diag('example path: ' . $f[0]);

@f = $m->_variant_list_files();
ok(scalar(@f), "identified " . scalar(@f) . " snp files w/o refseq filter");
ok(all_exist(@f),"the snp files exist")
    or diag('example path: ' . $f[0]);

@f = $m->_variant_detail_files();
ok(scalar(@f), "identified " . scalar(@f) . " pileup files w/o refseq filter");
ok(all_exist(@f),"the pileup files exist")
    or diag('example path: ' . $f[0]);

@f = $m->_variation_metrics_files();
ok(scalar(@f), "identified " . scalar(@f) . " variation metrics files w/o refseq filter");

SKIP: {
    skip 'We do not generate other_snp_related_metrics subdir right now', 1;
    ok(all_exist(@f),"the variation files exist");
}

$DB::single=1;
my $v = $m->variant_count();
is($v,6619300, "got expected variant count");

my $f;

my $data_directory = $m->complete_build_directory;
my $expected = '/gscmnt/sata821/info/model_data/2771359026/build96402993';
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

