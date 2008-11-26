#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 8;

my $x = Genome::InstrumentData::Solexa->create(-1);
ok($x, "created a solexa lane object");

$x->full_path("/my/path");
is($x->full_path,'/my/path', "set the full path on the main object");

my $a = $x->add_attribute(
    entity_class_name => 'Genome::InstrumentData::Solexa',
    property_name => "full_path2",
    value => "/my/path"
);
ok($a, "added an attribute the 'hard way'");
is($a->property_name, "full_path2", "property name is correct");
is($a->value, "/my/path", "vaue is correct");
is($a->entity,$x, "entity object is correct");
is($a->entity_id, $x->id, "entity id is correct");
isa_ok($x,$a->entity_class_name, "class is correct");

#my @d = Genome::InstrumentData::Solexa->get(full_path => "/my/path");
#is(scalar(@d),1, "got expected object returned by query");

#$HeadURL$
#$Id$
