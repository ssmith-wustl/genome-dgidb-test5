#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More;

use_ok('Genome::Model::Tools::ViromeEvent::BlastHumanGenome::ParseOutput');

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-ViromeScreening/Titanium17/Titanium17_undecodable';
ok( -d $data_dir, "Test suite data dir exists" );

my $c = Genome::Model::Tools::ViromeEvent::BlastHumanGenome::ParseOutput->create(
    dir => $data_dir,
    );

ok( $c, "Created blast human genome parse-output event" );

done_testing();

exit;
