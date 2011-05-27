#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require File::Compare;
require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::Assembly::Ace::ReplaceXsNs') or die;

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-ReplaceXsNs/v1';
my $in_acefile = $dir.'/in.ace';
ok(-s $in_acefile, 'in acefile');
my $example_acefile = $dir.'/example.ace';
ok(-s $example_acefile, 'example acefile');
my $tmpdir = File::Temp::tempdir(CLENUP => 1);
my $out_acefile = $tmpdir.'/out.ace';

# fails
my $failed_replacer;
$failed_replacer = Genome::Model::Tools::Assembly::Ace::ReplaceXsNs->execute();
ok(!$failed_replacer, 'failed to execute w/o acefile');

# success
my $replacer = Genome::Model::Tools::Assembly::Ace::ReplaceXsNs->create(
    acefile => $in_acefile,
    output_acefile => $out_acefile,
);
ok($replacer, 'create');
ok($replacer->execute, 'execute');
is(File::Compare::compare($example_acefile, $out_acefile), 0, 'output acefiles match');

done_testing();
exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2010 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

