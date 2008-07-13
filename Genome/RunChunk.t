#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More tests => 2;

my $r = Genome::RunChunk::Solexa->create(run_name => "FOO", subset_name => 3);
ok($r, "created a run chunk");
is($r->full_name, "FOO/3", "name composition works");

