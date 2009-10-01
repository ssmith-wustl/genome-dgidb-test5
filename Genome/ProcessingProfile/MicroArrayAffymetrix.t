#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::ProcessingProfile::Test;

Genome::ProcessingProfile::MicroArrayAffymetrix::Test->runtests;

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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/ProcessingProfile/AmpliconAssembly.t $
#$Id: AmpliconAssembly.t 50362 2009-08-25 21:10:17Z ebelter $

