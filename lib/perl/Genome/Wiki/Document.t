#!/gsc/bin/perl


use above "Genome";
use Data::Dumper;

# use Test::More tests => 6;
use Test::More skip_all => "SKIPPING until ticket 67710 is resolved";

use_ok('Genome::Wiki::Document');

Genome::Config->dev_mode(1);

my $doc = Genome::Wiki::Document->get(title => 'Main Page');
ok($doc, 'get main page');

is($doc->environment(), 'dev', 'using dev instance of wiki');

diag('crude test of parsing');
ok($doc->user(), 'user');
ok($doc->timestamp(), 'timestamp');
ok($doc->content(), 'content');



