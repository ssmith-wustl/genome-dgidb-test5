use strict;
use warnings;

use Test::More;

use above 'Genome';

BEGIN {
    if (`uname -a` =~ /x86_64/) {
        plan tests => 7;
    } else {
        plan skip_all => 'Must run on a 64 bit machine';
    }
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
}


my $aligner_name = "bwa";
my $aligner_version = "0.5.9-pem0.1";
my $aligner_params = "-q 5 -t 4";

my $reference_model = Genome::Model::ImportedReferenceSequence->get(name => 'TEST-human');
ok($reference_model, "got reference model");

my $reference_build = $reference_model->build_by_version('2');
ok($reference_build, "got reference build");

my $dependency = $reference_build->append_to;
ok($dependency, "found reference build dependency");

my %params = (
    aligner_name => $aligner_name,
    aligner_version => $aligner_version,
    aligner_params => $aligner_params,
    reference_build => $reference_build
    );

my %dep_params = %params;
$dep_params{reference_build} = $dependency;
my $index = Genome::Model::Build::ReferenceSequence::AlignerIndex->get(%dep_params);
ok(!$index, "index does not yet exist for dependency");

$index = Genome::Model::Build::ReferenceSequence::AlignerIndex->create(%params);
ok($index, "created index");

$index = Genome::Model::Build::ReferenceSequence::AlignerIndex->get(%params);
ok($index, "got index");

$index = Genome::Model::Build::ReferenceSequence::AlignerIndex->get(%dep_params);
ok($index, "got index of dependency");
