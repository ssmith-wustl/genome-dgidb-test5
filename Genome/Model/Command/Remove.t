#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 11;

BEGIN {
        use_ok('Genome::Model::Command::Remove');
}
my $archive_dir = File::Temp::tempdir(CLEANUP => 1);
my $data_dir = File::Temp::tempdir(CLEANUP => 1);
my $template = 'Genome-Model-Command-Remove-'. $ENV{USER} .'-XXXX';
my (undef,$archive_file) = File::Temp::tempfile(
                                                $template,
                                                SUFFIX => '.tgz',
                                                UNLINK => 1,
                                                DIR => $archive_dir
                                            );

my $mock_id = 0;
my $pp = Genome::ProcessingProfile->create_mock(id => --$mock_id);
my $model = Genome::Model->create_mock(
                                       id => --$mock_id,
                                       genome_model_id => $mock_id,
                                       subject_type => 'mock_subject_type',
                                       subject_name => 'mock_subject_name',
                                       subject_id   => --$mock_id,
                                       subject_class_name => 'Test::MockObject',
                                       name => 'mock_genome_model_name',
                                       processing_profile_id => $pp->id,
                                       data_directory => $data_dir,
                                   );
$model->set_always('yaml_string', 'I am a yaml string of this model.');
$model->set_always('resolve_archive_file', $archive_file );
$model->mock('delete',sub { return; });
my $remove_cmd;

#This should not create
eval {
    $remove_cmd = Genome::Model::Command::Remove->create();
};
ok(!$remove_cmd,'no model defined');

#This should create
$remove_cmd = Genome::Model::Command::Remove->create(model_id => $model->id);
ok($remove_cmd,'Model remove command created');
ok(!$remove_cmd->archive,'Do not archive model');
ok(!$remove_cmd->force_delete,'Do not force delete model');
$remove_cmd->force_delete(1);
ok($remove_cmd->force_delete,'force delete model');

#The model delete will cause this to fail
my $rv;
eval {
    $rv = $remove_cmd->execute
};
ok(!$rv,'remove model did not work because model delete failed');

#The model delete should work this time
$model->mock('delete',sub { return 1; });
$remove_cmd = Genome::Model::Command::Remove->create(
                                                     model_id => $model->id,
                                                     force_delete => 1,
                                                 );

ok($remove_cmd->execute,'delete model did work');

#No lets try archiving
$remove_cmd = Genome::Model::Command::Remove->create(
                                                     model_id => $model->id,
                                                     force_delete => 1,
                                                     archive => 1,
                                                 );
ok($remove_cmd->archive,'archive model is on');
ok($remove_cmd->execute,'archive and remove model');
ok(-s $archive_file,'archive file exists with size');
exit;
