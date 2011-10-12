#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Command::CopyFiles') or die;

# sample/pp/model/build
my $sample = Genome::Sample->create(
    id => -1234,
    name => 'H_GV-933124G-S.MOCK',
    taxon_id => 2863615589,
);
ok($sample, 'create sample');

my $pp = Genome::ProcessingProfile->create(
    type_name => 'metagenomic composition 16s',
    name => 'MC16s Sanger TEST',
    sequencing_platform => 'sanger',
    amplicon_processor => 'filter by-min-length --length 1150',
    sequencing_center => 'gsc',
    assembler => 'phred_phrap',
    assembler_params => '-vector_bound 0 -trim_qual 0',
    classifier => 'rdp2-1',
    classifier_params => '-training_set broad',
);
ok($pp, 'create sanger pp') or die;

my $model = Genome::Model::MetagenomicComposition16s->create(
    processing_profile => $pp,
    processing_profile => $pp,
    subject_name => $sample->name,
    subject_type => 'sample_name'
);
ok($model, 'MC16s sanger model') or die;

my $example_build = Genome::Model::Build->create(
    model=> $model,
    data_directory => '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSanger/build',
    id => -2288
);
ok($example_build, 'example build') or die;
ok($example_build->get_or_create_data_directory, 'resolved data dir');
is($example_build->the_master_event->event_status('Succeeded'), 'Succeeded', 'build is succeeded');
ok($example_build->the_master_event->date_completed( UR::Time->now ), 'build has date completed');

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

# ok - list w/ model name
my $copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->create(
    build_identifiers => $model->name,
    file_type => 'oriented_fasta',
    list => 1,
);
ok($copy_cmd, 'create command');
$copy_cmd->dump_status_messages(1);
ok($copy_cmd->execute, 'Execute list ok');

# ok - copy
#  tests multiple build retrieving methods: model id and build id
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->last_complete_build->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute copy ok',
);
my @files = glob("$tmpdir/*");
is(scalar @files, 1, 'Copied files');

# fail - copy to existing
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
);
ok(
    $copy_cmd && !$copy_cmd->result,
    'Failed as expected - no copy to existing file',
);

# ok - force copy
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->name,
    file_type => 'processed_fasta',
    destination => $tmpdir,
    force => 1,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute copy ok',
);

# fail - no type
ok(
    !Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
        build_identifiers => $model->id,
    ),
    'Failed as expected - no type',
);

# fail - invalid type
ok(
    !Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
        build_identifiers => $model->id,
        file_type => 'some_file_type_that_is_not_valid',
    ),
    'Failed as expected - no type',
);

done_testing();
exit;

