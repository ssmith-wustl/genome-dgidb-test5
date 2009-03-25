package Genome::Model::AmpliconAssembly::Report;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::AmpliconAssembly::Report {
    is => 'Genome::Report::Generator',
    has_many => [
    build_ids => {
        is => 'Integer',
        doc => 'Build ids to generate assembly stats report.',
    },
    builds => {
        is => 'Genome::Model::Build',
        id_by => 'build_ids',
    },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->build_ids ) {
        $self->error_message("Need build_ids to gererate report");
        $self->delete;
        return;
    }

    return $self;
}

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

