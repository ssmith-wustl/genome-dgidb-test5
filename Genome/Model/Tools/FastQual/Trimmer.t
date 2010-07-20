#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Tools::FastQual::Trimmer') or die;

# Class for testing
class Genome::Model::Tools::FastQual::Trimmer::Tester {
    is => 'Genome::Model::Tools::FastQual::Trimmer',
};
sub Genome::Model::Tools::FastQual::Trimmer::Tester::_trim {
    return 1;
}

my $trimmer = Genome::Model::Tools::FastQual::Trimmer::Tester->create();
ok($trimmer, 'create trimmer');
can_ok($trimmer, 'execute'); # test execute?? others under trimmer already do...

# Trim fail
eval{ # undef
    $trimmer->trim();
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to trim w/o array ref');
eval{ # string
    $trimmer->trim('aryref');
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to trim w/o array ref');
eval{ # empty ary ref
    $trimmer->trim([]);
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to trim w/ empty array');

# Trim OK
ok($trimmer->trim([{}]), 'trim');

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

