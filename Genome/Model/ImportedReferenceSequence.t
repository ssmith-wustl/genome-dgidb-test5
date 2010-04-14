#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More tests => 8;
use Data::Dumper;

BEGIN
{
    use_ok("Genome::Model::ImportedReferenceSequence");
}

my $model = Genome::Model::ImportedReferenceSequence->get(2741951221);
isa_ok( $model, 'Genome::Model::ImportedReferenceSequence' );
#my $build = $model->build_by_version(36);    # returns a hashref
# The test wants to retrieve an old build for ncbi-human 36 that have
# a version attribute and that would conflict with a newer build if it did.
# So, we ensure that it gets the old version.
my $build = Genome::Model::Build::ImportedReferenceSequence->get(93636924);

#print $build,"\n";
#print Dumper($build),"\n";
my $expected_dir
    = '/gscmnt/sata835/info/medseq/model_data/2741951221/v36-build93636924';

#print $build->data_directory(),"\n";
is( $build->data_directory(), $expected_dir, 'got the right data directory' );

#print $build->get_bases_file(1),"\n";
my $bases_file = $build->get_bases_file(1);
my $expected_bases_file
    = '/gscmnt/sata835/info/medseq/model_data/2741951221/v36-build93636924/1.bases';
is( $bases_file, $expected_bases_file, 'bases file correct' );

#print $build->sequence($bases_file, 1, 10),"\n";
my $test_seq0 = $build->sequence( $bases_file, 1, 10 );
my $expected_seq0 = 'TAACCCTAAC';
is( $test_seq0, $expected_seq0,
    'got expected sequence from start of file (via Build...)' );

#print $build->sequence($bases_file, 247249709, 247249719),"\n";
my $expected_seq1 = 'NNNNNNNNNNN';
my $test_seq1 = $build->sequence( $bases_file, 247249709, 247249719 );
is( $test_seq1, $expected_seq1,
    'got expected sequence from end of file (via Build...)' );

# this is from the model, not the build, but seems to work the same.
#print $model->sequence($bases_file, 1, 10);
my $model_seq0 = $model->sequence( $bases_file, 1, 10 );
is( $model_seq0, $expected_seq0,
    'expected seq from start of file (via Genome::Model::ImportedRefSeq...)'
);

my $model_seq1 = $model->sequence( $bases_file, 247249709, 247249719 );
is( $model_seq1, $expected_seq1,
    'expected seq from end of file (via Genome::Model::ImportedRefSeq...)' );
