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

for my $set_name ( $build->amplicon_set_names, 'none' ) {
    my $fasta_file = $build->processed_fasta_file_for_set_name($set_name);
    ok($fasta_file, "fasta file for $set_name");
    ok(!-e $fasta_file, "fasta file for $set_name does not exist");
}

my $pid = Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa->create( build => $build );
ok ( $pid, 'Create' );
ok ( $pid->execute, 'execute' );


my @expected_set_names = qw/  V1_V3 V3_V5 /;

for my $set_name ( @expected_set_names ) {
    my $fasta_file = $build->processed_fasta_file_for_set_name( $set_name );
    ok ( -s $fasta_file, "Got expected fasta file for set name: $set_name exists" );
}

my @not_expected_set_names = qw/ V6_V9 none /;
for my $set_name ( @not_expected_set_names ) {
    my $fasta_file = $build->processed_fasta_file_for_set_name( $set_name );
    ok (! -s $fasta_file, "Did not get fasta file for unexpected set name: $set_name" );
}

is($build->amplicons_attempted, 600, 'amplicons attempted is 600');

done_testing();

exit;
