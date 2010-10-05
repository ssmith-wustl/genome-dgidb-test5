#!/usr/bin/env perl
use strict;
use warnings;
BEGIN { $ENV{UR_DBI_NO_COMMIT} = 1; };
use above 'Genome';
use Test::More tests => 8;

my $m1 = Genome::Model->get(2851746104);
ok($m1, "$m1");

my $b1_1 = Genome::Model::Build->create(model_id => $m1->id);
isa_ok($b1_1,"Genome::Model::Build::MetagenomicComposition16s::Sanger");
# remove the lock on the model that is normally removed when the UR::Context is committed or rolled back
unlink('/gsc/var/lock/build_start/2851746104');

my $b1_2 = Genome::Model::Build::MetagenomicComposition16s->create(model_id => $m1->id);
isa_ok($b1_2,"Genome::Model::Build::MetagenomicComposition16s::Sanger");

my $m2 = Genome::Model->get(2850972264);
ok($m2, "$m2");

my $b2_1 = Genome::Model::Build->create(model_id => $m2->id);
isa_ok($b2_1,"Genome::Model::Build::ReferenceAlignment::Solexa");
# remove the lock on the model that is normally removed when the UR::Context is committed or rolled back
unlink('/gsc/var/lock/build_start/2850972264');

my $b2_2 = Genome::Model::Build::ReferenceAlignment->create(model_id => $m2->id);
isa_ok($b2_2,"Genome::Model::Build::ReferenceAlignment::Solexa");


for my $model_id ($m1->id, $m2->id) {
    my @out = `bash -c 'genome model build list $model_id 2>&1'`;
    my @err = grep { /ERROR|WARNING/ } @out;
    is(scalar(@err),0, "no errors or warnings") or diag(@out);
}

