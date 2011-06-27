#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require Genome::Model::Test;
use Test::More tests => 3;

BEGIN {
    use_ok('Genome::Model::Command');
}


my $model = Genome::Model::Test->create_basic_mock_model(type_name => 'tester');
ok($model, 'Created mock model');
my $command = Genome::Model::Command->create(
                                             model => $model,
                                         );
isa_ok($command,'Genome::Model::Command');

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
