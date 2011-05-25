#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require Genome::Model::Test;
use Test::More tests => 13;

BEGIN {
    use_ok('Genome::Model::Command::InstrumentData::List');
}

my $m = Genome::Model::Test->create_basic_mock_model(type_name => 'tester');
my @id = Genome::Model::Test->create_mock_solexa_instrument_data(2);
Genome::Model::Test->create_mock_instrument_data_assignments($m, $id[0]);
$m->set_list('compatible_instrument_data', @id);

#< Successes >#
# list assigned
my $lister = Genome::Model::Command::InstrumentData::List->create(model_id => $m->id);
ok($lister, 'Created the lister');
isa_ok($lister, 'Genome::Model::Command::InstrumentData::List');
ok($lister->execute, 'Show assigned instrument data');
# list compatible
$lister = Genome::Model::Command::InstrumentData::List->create(
    model_id => $m->id,
    compatible => 1,
);
ok($lister, 'Created the lister for compatible inst data');
isa_ok($lister, 'Genome::Model::Command::InstrumentData::List');
ok($lister->execute, 'Show compatable instrument data');

#< Fails >#
# no model id
$lister = Genome::Model::Command::InstrumentData::List->create();
ok($lister, 'Created the lister w/o model id');
isa_ok($lister, 'Genome::Model::Command::InstrumentData::List');
ok(!$lister->execute, 'Execution fails as expected');
# assigned and compatible
$lister = Genome::Model::Command::InstrumentData::List->create(
    model_id => $m->id,
    assigned => 1,
    compatible => 1,
);
ok($lister, 'Created the lister trying to list assigned AND compatible inst data');
isa_ok($lister, 'Genome::Model::Command::InstrumentData::List');
ok(!$lister->execute, 'Execution fails as expected');


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

