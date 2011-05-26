#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require Genome::Model::Test;
use Test::More 'no_plan';

use_ok('Genome::Model::Command::Rename');

# MOCK 
my $model = Genome::Model::Test->create_basic_mock_model(type_name => 'amplicon assembly')
    or die "Can't create mock model for amplicon assembly\n";

my $new_name = 'mrs. mock';
my $old_name = $model->name; # should be 'mr. mock'

# SUCCESS
my $renamer = Genome::Model::Command::Rename->create(
    from => $model,
    to => $new_name,
);
ok($renamer->execute, 'Execute renamer');
is($model->name, $new_name, 'Renamed model');
$renamer->delete;
$model->name($old_name); # reset for testing below

# FAIL - FYI not testing w/o model id - that should already be covered on other tests
# no name - fails on create
ok(!Genome::Model::Command::Rename->execute(from => $model), 'Failed as expected - create w/o new name');
# create w/ name, then undef - fails on execute
$renamer = Genome::Model::Command::Rename->create(from => $model, to => $new_name);
$renamer->to(undef);
ok(!$renamer->execute, 'Failed as expected - execute w/ undef name');
$renamer->delete;
# create and execute w/ old name
$renamer = Genome::Model::Command::Rename->create(from => $model, to => $old_name);
ok(!$renamer->execute, 'Failed as expected - execute w/ same name');
$renamer->delete;

exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
