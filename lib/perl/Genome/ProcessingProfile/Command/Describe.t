#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
require Genome::ProcessingProfile::Test;

use_ok('Genome::ProcessingProfile::Command::Describe') or die;

my $pp = Genome::ProcessingProfile::Test->create_mock_processing_profile('tester');
ok($pp, "Created processing profile to test renaming") or die;

my $describer = Genome::ProcessingProfile::Command::Describe->create(processing_profiles => [$pp]);
ok($describer, 'Created the describer');
isa_ok($describer, 'Genome::ProcessingProfile::Command::Describe');
ok($describer->execute, 'Executed the describer');

done_testing();
exit;

