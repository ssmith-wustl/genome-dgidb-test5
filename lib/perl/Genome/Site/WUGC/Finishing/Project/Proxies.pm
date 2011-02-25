package Finishing::Project::BaseProxy;

use strict;
use warnings;

use Data::Dumper;
use Finfo::ClassUtils 'class';
use Finfo::Std;

my %source :name(source:r)
    :isa('object Finishing::Project::Source GSC::Project');

sub source_attributes
{
    my $self = shift;

    return;
}

sub get_attribute_subroutine
{
    my ($self, $attr, @args) = @_;

    my $source = $self->source;

    $self->fatal_msg
    (
        sprintf('Invalid attribute (%s) for source (%s)', $attr, class($source) )
    ) unless grep { $attr eq $_ } $self->source_attributes;

    return sub{ return $source->$attr(@args); }
}

##################################################################################
##################################################################################

package Finishing::Project::Proxy;

use strict;
use warnings;

use base 'Finishing::Project::BaseProxy';

sub source_attributes
{
    return (qw/ name dir /);
}

##################################################################################
##################################################################################

package Finishing::Project::GSCProxy;

use strict;
use warnings;

use base 'Finishing::Project::BaseProxy';

sub source_attributes
{
    return
    (
        GSC::Project->property_names,
        (qw/
            consensus_abs_path get_accession_numbers
            finisher_unix_login 
            finisher_group
            claim_date
            prefinisher_unix_login
            get_neighbor_info_from_tilepath
            get_species_name get_chromosome
            get_projects_submission_pses get_projects_last_submission_pse
            /)
    );
}

##################################################################################
##################################################################################

1;

=pod

=head1 Name

Finishing::Project::Proxy

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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/Proxies.pm $
#$Id: Proxies.pm 29849 2007-11-07 18:58:55Z ebelter $

