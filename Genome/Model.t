#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 12;

my $m = Genome::Model->get(name => 'AML-skin1-new_maq-no_dups');
ok($m, "got a model"); 

my @f = $m->_consensus_files('X');
ok(scalar(@f), "identified " . scalar(@f) . " consensus file by refseq");

    my @f2 = $m->assembly_file_for_refseq('X');
    is("@f2","@f","old consensus method matches new with a refseq");

@f = $m->_consensus_files();
ok(scalar(@f), "identified " . scalar(@f) . " consensus files w/o refseq filter");
ok(all_exist(@f),"the consensus files exist");

@f = $m->_variant_list_files();
ok(scalar(@f), "identified " . scalar(@f) . " snp files w/o refseq filter");
ok(all_exist(@f),"the snp files exist");

@f = $m->_variant_detail_files();
ok(scalar(@f), "identified " . scalar(@f) . " pileup files w/o refseq filter");
ok(all_exist(@f),"the pileup files exist");

my $v = $m->variant_count();
is($v,4071837, "got expected variant count");

my $f;

my $data_directory = $m->data_directory;
is($data_directory, "/gscmnt/sata114/info/medseq/model_data/H_GV-933124G-skin1-9017g_AML-skin1-new_maq-no_dups", "resolved data directory");  # FIX WHEN WE SWITCH MODELS

#$f = $m->resolve_accumulated_alignments_filename();
#is($f, 'FIXME', "found accumulated alignments file name"); #FIXME WHEN WE SWITCH MODELS

$f = $m->alignments_maplist_directory();
is($f, "$data_directory/alignments.maplist", "found maplist");

#@f = $m->maplist_file_paths();
#is(scalar(@f), 'FIXME', "found maplist file paths"); #FIXME WHEN WE SWITCH MODELS

sub all_exist {
    return (!(grep{ ! -e $_ } @_) ? 1 : 0);
}

