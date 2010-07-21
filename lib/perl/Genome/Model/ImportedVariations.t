
use strict;
use warnings;
use above "Genome";

use Test::More tests => 3;

BEGIN
{
    use_ok("Genome::Model::ImportedVariations");
}

my $model = Genome::Model::ImportedVariations->get(2857166586);
isa_ok($model, "Genome::Model::ImportedVariations");
ok($model->name, 'dbSNP-human-130');
