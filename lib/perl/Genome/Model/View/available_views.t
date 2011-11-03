#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above 'Genome';

use Test::More tests => 6;

my $type = UR::Object::Type->get(class_name => 'Genome::Model');
ok($type, 'got a meta-object for the model class');

my $view = $type->create_view(perspective => 'available-views', toolkit => 'xml');
ok($view, 'got a view for that meta-object');

my $content = $view->content;
ok($content, 'generated content for that view');

ok($content =~ /<toolkit name=.text./i, 'view returned some toolkits');
ok($content =~ /<perspective name=.default./i, 'view included at least the default perspective');

my $err = $view->error_message;
ok(!$err, 'no errors in view creation');
