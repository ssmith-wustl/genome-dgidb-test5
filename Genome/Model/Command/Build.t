#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

use above "Genome";

use IO::Socket;
use IO::Select;

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

# The call to Solexa->create() below is expected to fail.  Normally we'd just set the
# errror messages to queue up and interrogate them later, but since the create() call 
# doesn't return aything, we instead need to set up an alternate file handle for the
# errors to get printed to
my $read = IO::Handle->new;
my $write = IO::Handle->new;
pipe($read,$write);
$write->autoflush(1);
Genome::Model::Command::Build::ReferenceAlignment::Solexa->dump_error_messages($write);
my $build = Genome::Model::Command::Build::ReferenceAlignment::Solexa->create(model_id => $model->id,);
$write->close();

ok(!$build,'build should fail create with no read sets');

my $select = IO::Select->new($read);
if ($select->can_read(0)) {
    my @errors = $read->getlines();
    chomp(@errors);
    ok(scalar(@errors), 'build generated at least one error');
    is($errors[0], "ERROR: No read sets have been added to model: test", 'Error message line 1 ok');
    is($errors[1], "ERROR: The following command will add all available read sets:", 'Error message line 2 ok');
    like($errors[2], qr(^genome-model add-reads --model-id=\w+ --all), 'Error message line 3 ok');

} else {
    ok(0, "Didn't see any error messages");
}


exit;
