#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Model::Command::Input::Names') or die;

no warnings qw/ redefine once /;
*Genome::Model::Command::get_model_type_names = sub{ return ('reference alignment'); };
use warnings;
my @type_names = Genome::Model::Command->get_model_type_names;
is_deeply(\@type_names, [ 'reference alignment' ], 'overload type names');

note('Names');
my $names = Genome::Model::Command::Input::Names->create(
    type_name => 'reference alignment',
);
ok($names, 'create');
ok($names->execute, 'execute');

note('Fail - no tester model type');
$names = Genome::Model::Command::Input::Names->create(
    type_name => 'none',
);
ok($names, 'create');
ok(!$names->execute, 'execute');

done_testing();
exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2009 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

