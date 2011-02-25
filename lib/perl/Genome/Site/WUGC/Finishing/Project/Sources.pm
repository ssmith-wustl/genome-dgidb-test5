package Finishing::Project::BaseSource;

use strict;
use warnings;

use Finfo::Std;

my %name :name(name:o)
    :isa('string');
my %dir :name(dir:r)
    :isa('dir_rw');

##################################################################################
##################################################################################

package Finishing::Project::Source;

use strict;
use warnings;

use base 'Finishing::Project::BaseSource';

##################################################################################
##################################################################################

1;

=pod

=head1 Name

Finishing::Project::Source

=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 See Also

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/Sources.pm $
#$Id: Sources.pm 29849 2007-11-07 18:58:55Z ebelter $

