#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 13;

BEGIN {
    use_ok('Genome::Model::Command::InstrumentData::List');
}

#< Successes >#
# list assigned
my $lister = Genome::Model::Command::InstrumentData::List->create(model_id => 2725028123);
ok($lister, 'Created the lister');
isa_ok($lister, 'Genome::Model::Command::InstrumentData::List');
ok($lister->execute, 'Execution succeeds!');
# list compatible
$lister = Genome::Model::Command::InstrumentData::List->create(
    model_id => 2725028123,
    compatible => 1,
);
ok($lister, 'Created the lister for compatible inst data');
isa_ok($lister, 'Genome::Model::Command::InstrumentData::List');
ok($lister->execute, 'Execution succeeds!');

#< Fails >#
# no model id
$lister = Genome::Model::Command::InstrumentData::List->create();
ok($lister, 'Created the lister w/o model id');
isa_ok($lister, 'Genome::Model::Command::InstrumentData::List');
ok(!$lister->execute, 'Execution fails as expected');
# assigned and compatible
$lister = Genome::Model::Command::InstrumentData::List->create(
    model_id => 2725028123,
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

