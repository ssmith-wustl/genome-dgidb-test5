
use strict;
use warnings;
use above;

use Test::More tests => 5;

BEGIN
{
    use_ok("Genome::Model::ImportedAnnotation");
}

my $model = Genome::Model::ImportedAnnotation->get(2771411739);
isa_ok($model, "Genome::Model::ImportedAnnotation");
ok($model->name, 'human.imported-annotation-NCBI-human-36');
my $build = $model->build_by_version(0);
ok($build, 'got build by version 0');
isa_ok($build, "Genome::Model::Build::ImportedAnnotation");
