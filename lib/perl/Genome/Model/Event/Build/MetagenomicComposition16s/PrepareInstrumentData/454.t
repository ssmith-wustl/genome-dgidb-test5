#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
use Genome::Model::MetagenomicComposition16s::Test;

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454') or die;

my $model = Genome::Model::MetagenomicComposition16s::Test->model_for_454;
ok($model, 'got mc16s 454 model');
my $build = $model->create_build(
    model => $model,
    data_directory => $model->data_directory,
);
ok($build, 'created build');

# make sure fasta file do not exist
for my $set_name ( $build->amplicon_set_names, 'none' ) {
    my $fasta_file = $build->processed_fasta_file_for_set_name($set_name);
    ok($fasta_file, "fasta file for $set_name");
    ok(!-e $fasta_file, "fasta file for $set_name does not exist");
}

# run
my $pid = Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454->create(build => $build);
ok($pid, 'create');
$pid->dump_status_messages(1);
ok($pid->execute, 'execute');

# make sure fasta file do exist
for my $set_name ( $build->amplicon_set_names, 'none' ) {
    my $fasta_file = $build->processed_fasta_file_for_set_name($set_name);
    ok($fasta_file, "fasta file for $set_name");
    ok(-s $fasta_file, "fasta file for $set_name was created");
}

# metrics
is($build->amplicons_attempted, 20, 'amplicons attempted is 20');
is($build->reads_attempted, 20, 'reads attempted is 20');
is($build->reads_processed, 19, 'reads processed is 19');
is($build->reads_processed_success, '0.95', 'reads processed success is 0.95');

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

