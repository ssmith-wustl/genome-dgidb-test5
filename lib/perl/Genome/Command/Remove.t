#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::MockObject;
use Test::More;

my $i = Test::MockObject->new();
$i->set_isa('Genome::Model', 'UR::Object');
$i->set_always('__display_name__', "Mock Model 1");
$i->set_always('__label_name__', "Mock Model");
$i->set_always('delete', 1);
ok($i, "created mock model 1");

my $i2 = Test::MockObject->new();
$i2->set_isa('Genome::Model', 'UR::Object');
$i2->set_always('__display_name__', "Mock Model 2");
$i2->set_always('__label_name__', "Mock Model");
$i2->set_always('delete', 1);
ok($i2, "created mock model 2");

my $remove_command = Genome::Command::Remove->create(items => [$i, $i2]);
ok($remove_command->execute(), "command succeeded");

done_testing();
