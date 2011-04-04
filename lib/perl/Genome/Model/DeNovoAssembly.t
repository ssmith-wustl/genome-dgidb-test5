#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More 'no_plan';

use_ok('Genome::Model::DeNovoAssembly');

my $model = Genome::Model::DeNovoAssembly::Test->model_for_soap;
ok($model, 'mock model');
is($model->center_name, 'WUGC', 'center name');
is($model->default_model_name, 'Escherichia coli TEST.denovo-1', 'default model name');

my %tissue_descs_and_name_parts = (
    '20l_p' => undef,
    'u87' => undef,
    'zo3_G_DNA_Attached gingivae' => 'Attached Gingivae',
    'lung, nos' => 'Lung Nos',
    'mock community' => 'Mock Community',
);
for my $tissue_desc ( keys %tissue_descs_and_name_parts ) {
    my $name_part = $model->_get_name_part_from_tissue_desc($tissue_desc);
    is($name_part, $tissue_descs_and_name_parts{$tissue_desc}, 'tissue desc converted to name part');
}

exit;

