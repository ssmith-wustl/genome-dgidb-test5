#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
use Genome::Model::MetagenomicComposition16s::Test;

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa') or die;

my $model = Genome::Model::MetagenomicComposition16s::Test->model_for_solexa;
ok( $model, "Got mc16s solexa model" );

my $build = Genome::Model::Build->create(
    model => $model,
    data_directory => $model->data_directory,
);
ok($build, 'created build');

my $pid = Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa->create( build => $build );
ok ( $pid, 'Create' );
ok ( $pid->execute, 'execute' );

my $input_fasta = $build->combined_input_fasta_file;
ok( -s $input_fasta, "Combined input fasta file" );

is($build->amplicons_attempted, 600, 'amplicons attempted is 600');

#<STDIN>;

done_testing();

exit;
