#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::MetagenomicComposition16s::Test;

Genome::Model::MetagenomicComposition16s::Report::SummarySanger::Test->runtests;

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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/AmpliconAssembly/Report/Stats.t $
#$Id: Stats.t 50511 2009-08-28 19:30:32Z ebelter $
