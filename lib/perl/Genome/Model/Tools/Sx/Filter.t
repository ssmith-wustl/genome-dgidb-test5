#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Tools::FastQual::Filter') or die;

# Class for testing
class Genome::Model::Tools::FastQual::Filter::Tester {
    is => 'Genome::Model::Tools::FastQual::Filter',
};
sub Genome::Model::Tools::FastQual::Filter::Tester::_filter {
    return 1;
}

my $filter = Genome::Model::Tools::FastQual::Filter::Tester->create();
ok($filter, 'create filter');
can_ok($filter, 'execute'); # test execute?? others under filter already do...

# Filter fail
eval{ # undef
    $filter->filter();
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to filter w/o array ref');
eval{ # string
    $filter->filter('aryref');
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to filter w/o array ref');
eval{ # empty ary ref
    $filter->filter([]);
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to filter w/ empty array');

# Filter OK
ok($filter->filter([{}]), 'filter');

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

#$HeadURL$
#$Id$

