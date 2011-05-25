#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::Event::Build::AmpliconAssembly::Test;

Genome::Model::Event::Build::AmpliconAssembly::Reports::Test->runtests;

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
