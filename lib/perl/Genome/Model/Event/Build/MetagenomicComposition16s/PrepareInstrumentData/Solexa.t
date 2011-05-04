#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
use Genome::Model::MetagenomicComposition16s::Test;

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa') or die;

my $model = Genome::Model::MetagenomicComposition16s::Test->model_for_solexa;
ok( $model, "Got mc16s solexa model" );

my $build = $model->create_build(
    model => $model,
    data_directory => $model->data_directory,
);
ok($build, 'created build');

my $pid = Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa->create( build => $build );
ok ( $pid, 'Create' );
ok ( $pid->execute, 'execute' );

my $input_fasta = $build->combined_input_fasta_file;
ok( -s $input_fasta, "Combined input fasta file" );

# metrics
is($build->amplicons_attempted, 600, 'amplicons attempted is 600');
is($build->reads_attempted, 600, 'reads attempted is 600');
is($build->reads_processed, 600, 'reads processed is 600');
is($build->reads_processed_success, '1.00', 'reads processed success is 1.00');

#<STDIN>;
done_testing();
exit;
