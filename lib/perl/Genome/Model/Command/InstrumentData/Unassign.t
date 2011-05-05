#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use above 'Genome';

use Test::More tests => 18;

use_ok('Genome::Model::Command::InstrumentData::Unassign') or die;

my $pp = Genome::ProcessingProfile::TestPipeline->create(
    name => 'Test Pipeline Test for Testing',
    some_command_name => 'ls',
);
ok($pp, "created processing profile") or die;

my $model = Genome::Model->create(
    processing_profile => $pp,
    subject_name => 'human',
    subject_type => 'species_name',
    user_name => 'apipe',
);
ok($model, 'create model') or die;

my @sanger_id = map { Genome::InstrumentData::Sanger->create(id => '0'.$_.'jan00.101amaa') } (1..4);
is(scalar(@sanger_id), 4, 'create instrument data') or die;

my $flow_cell = Genome::InstrumentData::FlowCell->create(id => '__TEST_FLOW_CELL__');
ok($flow_cell, 'create flow cell') or die;
my $solexa_id = Genome::InstrumentData::Solexa->create(flow_cell_id => $flow_cell->id);
ok($solexa_id, 'create solexa inst data') or die;

for my $data (@sanger_id, $solexa_id) {
    $model->add_instrument_data($data);
}
my @assigned_inst_data = $model->instrument_data;
is(scalar(@assigned_inst_data), 5, 'instrument data is assigned to model');

# Fails
my $unassign = Genome::Model::Command::InstrumentData::Unassign->create(
    model_id => $model->id,
    all => 1,
    instrument_data_id => $solexa_id->id,
);
isa_ok($unassign, 'Genome::Model::Command::InstrumentData::Unassign', 'create to request multiple functions - will fail execute');
$unassign->dump_status_messages(1);
ok(!$unassign->execute, 'execute failed as expected');

# Success
$unassign = Genome::Model::Command::InstrumentData::Unassign->create(
    model_id => $model->id,
    instrument_data_id => $sanger_id[0]->id,
);
isa_ok($unassign, 'Genome::Model::Command::InstrumentData::Unassign', 'create to unassign single instrument data');
$unassign->dump_status_messages(1);
ok($unassign->execute, 'execute single unassign');
@assigned_inst_data = $model->instrument_data;
ok(!grep($_ eq $sanger_id[0], @assigned_inst_data), 'data is no longer assigned');

$unassign = Genome::Model::Command::InstrumentData::Unassign->create(
    model_id => $model->id,
    instrument_data_ids => join( ' ', $sanger_id[1]->id, $sanger_id[2]->id, ),
);
isa_ok($unassign, 'Genome::Model::Command::InstrumentData::Unassign', 'create to unassign multiple instrument data');
$unassign->dump_status_messages(1);
ok($unassign->execute, 'execute multiple unassign');
@assigned_inst_data = $model->instrument_data;
ok(!grep(($_ eq $sanger_id[1] || $_ eq $sanger_id[2]), @assigned_inst_data), 'data is no longer assigned');

$unassign = Genome::Model::Command::InstrumentData::Unassign->create(
    model_id => $model->id,
    all => 1,
);
isa_ok($unassign, 'Genome::Model::Command::InstrumentData::Unassign', 'create to unassign all available instrument data');
$unassign->dump_status_messages(1);
ok($unassign->execute, 'execute');
@assigned_inst_data = $model->instrument_data;
is(scalar(@assigned_inst_data), 0, 'all data unassigned');

exit;

