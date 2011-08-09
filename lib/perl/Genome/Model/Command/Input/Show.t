#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Model::Command::Input::Show') or die;

my $show = Genome::Model::Command::Input::Show->create(
    model => 'reference alignment',
);
ok($show, 'create');
$show->dump_status_messages(1);
ok($show->execute, 'execute');

$show = Genome::Model::Command::Input::Show->create(
    model => 'none',
);
ok($show, 'create');
ok(!$show->execute, 'execute');

done_testing();
exit;

