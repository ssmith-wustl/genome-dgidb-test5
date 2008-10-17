#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

use above "Genome";


my $pp = Genome::ProcessingProfile::ReferenceAlignment->create(
                                                               name => 'test',
                                                               dna_type => 'genomic dna',
                                                               read_aligner_name => 'maq0_6_8',
                                                               sequencing_platform => 'solexa',
                                                               reference_sequence_name => 'refseq-for_test',
                                                           );
isa_ok($pp,'Genome::ProcessingProfile');
my $model = Genome::Model::ReferenceAlignment->create(
                                                      processing_profile_id => $pp->id,
                                                      name => 'test',
                                                  );
isa_ok($model,'Genome::Model');
my $build = Genome::Model::Command::Build::ReferenceAlignment::Solexa->create(model_id => $model->id,);
ok(!$build,'build should fail create with no read sets');

exit;
