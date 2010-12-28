#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

UR::DataSource->next_dummy_autogenerated_id;
do {
    $UR::DataSource::last_dummy_autogenerated_id = int($UR::DataSource::last_dummy_autogenerated_id / 10);
} until length($UR::DataSource::last_dummy_autogenerated_id) < 9;
diag('Dummy ID: '.$UR::DataSource::last_dummy_autogenerated_id);
cmp_ok(length($UR::DataSource::last_dummy_autogenerated_id), '<',  9, 'dummy id is shorter than 9 chars');

use_ok('Genome::Sample::Command::Import::Tcga') or die;

my $name = 'TCGA-00-0000-000-000-0000-00';
my $import_tcga = Genome::Sample::Command::Import::Tcga->create(
    name => $name,
);
ok($import_tcga, 'create');
$import_tcga->dump_status_messages(1);
ok($import_tcga->execute, 'execute');
is($import_tcga->_individual_name, 'TCGA-00-0000', 'individual name');
is($import_tcga->library->sample->name, $name, 'sample name');
is($import_tcga->library->name, $name.'-extlibs', 'library name');

my $commit = eval{ UR::Context->commit; };
ok($commit, 'commit');
                                                  
done_testing();
exit();

