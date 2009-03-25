#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 6;

use_ok('Genome::Model::Command::Build::AmpliconAssembly::Orient')
    or die;
use_ok('Genome::Model::AmpliconAssembly::Test') # necessary cuz mock objects are in here
    or die;
my $model = Genome::Model::AmpliconAssembly::Test->create_mock_model;
ok($model, 'Got mock amplicon assembly model');
my $build = $model->latest_complete_build;
ok($build, 'Got build from model');
Genome::Model::AmpliconAssembly::Test->copy_test_dir(
    'fasta',
    $build->fasta_dir,
)
    or die "Can't copy test data\n";
my $orient = Genome::Model::Command::Build::AmpliconAssembly::Orient->create(
    model => $model,
    build => $model->latest_complete_build,
);
ok($orient, "Created orient")
    or die;
ok($orient->execute, "Execute");

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

