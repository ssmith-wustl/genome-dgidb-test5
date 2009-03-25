#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 6;

use_ok('Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData')
    or die;
use_ok('Genome::Model::AmpliconAssembly::Test') # necessary cuz mock objects are in here
    or die;
my $model = Genome::Model::AmpliconAssembly::Test->create_mock_model;
ok($model, 'Got mock amplicon assembly model');
my $build = $model->latest_complete_build;
ok($build, 'Got build from model');
my $verify_inst_data = Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData->create(
    model => $model,
    build => $model->latest_complete_build,
);
ok($verify_inst_data, "Created verify instrument data")
    or die;
ok($verify_inst_data->execute, "Execute");

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

