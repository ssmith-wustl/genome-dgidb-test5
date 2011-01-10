#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

use_ok('Genome::Model::Command::Input::Update') or die;

my $model = Genome::Model::Test->create_mock_model(
    type_name => 'tester',
    instrument_data_count => 0,
) or die "Can't create mock tester model.";
ok($model, 'got model') or die 'Cannot get mock model';

note('Update');
my $update = Genome::Model::Command::Input::Update->create(
    model => $model,
    name => 'coolness',
    value => 'moderate',
);
ok($update, 'create');
$update->dump_status_messages(1);
ok($update->execute, 'execute');

note('Update to undef');
$update = Genome::Model::Command::Input::Update->create(
    model => $model,
    name => 'coolness',
    value => '',
);
ok($update, 'create');
$update->dump_status_messages(1);
ok($update->execute, 'execute');

note('Try to use update for is_many property');
$update = Genome::Model::Command::Input::Update->create(
    model => $model,
    name => 'friends',
    value => 'Watson',
);
ok($update, 'create');
$update->dump_status_messages(1);
ok(!$update->execute, 'execute');

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

