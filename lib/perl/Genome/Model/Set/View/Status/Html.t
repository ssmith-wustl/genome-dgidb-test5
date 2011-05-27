#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::Model::Set::View::Status::Html') or die;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

my $pp = Genome::ProcessingProfile::TestPipeline->create(
    name => 'Test Pipeline Test for Testing',
    some_command_name => 'ls',
);
ok($pp, "created processing profile") or die;
my @models;
for my $i (1..2) {
    push @models, Genome::Model->create(
        name => $pp->name.'-'.$i,
        processing_profile => $pp,
        subject_name => 'human',
        subject_type => 'species_name',
        user_name => 'apipe',
    ) or die;
}
is(@models, 2, "created 2 models");

my $set = Genome::Model->define_set(processing_profile_id => $pp->id);
ok($set, "defined a model set") or die;
my @members = $set->members;
is_deeply([ sort { $a->id <=> $b->id } @models ], [ sort { $a->id <=> $b->id } @members ], 'set members match models');

my $view_obj = $set->create_view(
    xsl_root => Genome->base_dir . '/xsl',
    rest_variable => '/cgi-bin/rest.cgi',
    toolkit => 'html',
    perspective => 'status',
); 
ok($view_obj, "created a view") or die;
isa_ok($view_obj, 'Genome::Model::Set::View::Status::Html');

my $html = $view_obj->_generate_content();
ok($html, "view returns HTML") or die;

done_testing();
exit;

