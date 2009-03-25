#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 6;

use_ok('Genome::Model::Command::Build::AmpliconAssembly::Assemble')
    or die;
use_ok('Genome::Model::AmpliconAssembly::Test') # necessary cuz mock objects are in here
    or die;
my $model = Genome::Model::AmpliconAssembly::Test->create_mock_model;
ok($model, 'Got mock amplicon assembly model');
my $build = $model->latest_complete_build;
ok($build, 'Got build from model');
$build->link_instrument_data( $model->instrument_data )
    or die "Can't link traces\n";
my $assemble = Genome::Model::Command::Build::AmpliconAssembly::Assemble->create(
    model => $model,
    build => $build,
);
ok($assemble, "Created assemble")
    or die;
ok($assemble->execute, "Execute");

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

