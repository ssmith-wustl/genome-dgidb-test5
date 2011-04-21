#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More;

my $abyss_version = '1.2.7';
my $class = "Genome::Model::Tools::Abyss::Parallel";
use_ok($class);

my $obj = $class->create(version => $abyss_version, params => "np=16");
ok($obj, "created object");

ok(-x $obj->abyss_pe_binary, "default executable exists at ".$obj->abyss_pe_binary);

is($obj->job_count, 16, "job count parsed correctly from params");

$obj->params(" np=8");
is($obj->job_count, 8, "job count parsed correctly from params");

$obj->params("np=12 ");
is($obj->job_count, 12, "job count parsed correctly from params");

$obj->params(" np=24 ");
is($obj->job_count, 24, "job count parsed correctly from params");

$obj->params("onp=8a");
is($obj->job_count, 1, "job count parsed correctly from params");

$obj->params("onp=8");
is($obj->job_count, 1, "job count parsed correctly from params");

$obj->params("np=8a");
is($obj->job_count, 1, "job count parsed correctly from params");

done_testing();
