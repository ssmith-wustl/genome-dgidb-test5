#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More;

use_ok('Genome::Model::Tools::ViromeEvent::CDHIT::CheckResult');
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-ViromeScreening/Titanium17/Titanium17_undecodable';

#check cd-hit directoryies
ok( -x '/gscmnt/sata835/info/medseq/virome/scripts_used_by_virome/cd-hit-64/cd-hit-est', "64 bit cd-hit exists and is executable" );
ok( -x '/gscmnt/sata835/info/medseq/virome/scripts_used_by_virome/cd-hit-32/cd-hit-est', "64 bit cd-hit exists and is executable" );

my $cr = Genome::Model::Tools::ViromeEvent::CDHIT::CheckResult->create(
    dir => $data_dir,
    );

ok( $cr, "Created virome check-result event" );

done_testing();

exit;
