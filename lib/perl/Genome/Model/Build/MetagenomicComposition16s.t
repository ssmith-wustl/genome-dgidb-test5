#! /gsc/bin/perl
#
#
#
#
# All methods in the build are tested in the subclasses - only use_ok here
#
#
#
#
#

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 1;

use_ok('Genome::Model::Build::MetagenomicComposition16s');

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

 Eddie Belter <ebelter@genome.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/MetagenomicComposition16s.t $
#$Id: MetagenomicComposition16s.t 56090 2010-03-03 23:57:25Z ebelter $
