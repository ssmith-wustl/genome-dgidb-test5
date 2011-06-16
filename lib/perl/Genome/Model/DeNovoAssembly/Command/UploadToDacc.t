#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::DeNovoAssembly::Command::UploadToDacc') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_soap;
ok($model, 'Got de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($build, 'Got example de novo assembly build') or die;
$build->assembly_length(100000);

$build->status('Succeeded');
$build->the_master_event->date_completed(UR::Time->now);
no warnings;
*Genome::Sys::shellcmd = sub{ return 1; };
use warnings;
ok(Genome::Sys->shellcmd(), 'shellcmd overloaded');

my $uploader = Genome::Model::DeNovoAssembly::Command::UploadToDacc->create(
    model => $model,
);
ok($uploader, 'create');
$uploader->dump_status_messages(1);
ok($uploader->execute, 'execute');

done_testing();
exit;

