#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 6;

use Genome::Utility::FileSystem;

my $tmp = Genome::Utility::FileSystem->create_temp_directory();

#my $tmp = File::Temp::tempdir(CLEANUP=>0);

# TODO: use a "testing" cDNA model to get build rather than this real build
my $build_id = '98203530';
my $build = Genome::Model::Build->get($build_id);
ok($build, "build found with id $build_id");

my $r = Genome::Model::ReferenceAlignment::Report::ReferenceCoverage->create(
    build_id => $build_id,
);
ok($r, "created a new report");

my $v = $r->generate_report;
ok($v, "generation worked");

my $result = $v->save($tmp);
ok($result, "saved to $tmp");

my $name = $r->name;
$name =~ s/ /_/g;

ok(-d "$tmp/$name", "report directory $tmp/$name is present");
ok(-e "$tmp/$name/report.xml", 'xml report is present');



