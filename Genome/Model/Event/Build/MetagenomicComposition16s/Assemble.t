#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::MetagenomicComposition16s::Test;

Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::Test->runtests;

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

#$HeadURL$
#$Id$

