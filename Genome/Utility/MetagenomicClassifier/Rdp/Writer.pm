package Genome::Utility::MetagenomicClassifier::Rdp::Writer;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Utility::MetagenomicClassifier::Rdp::Writer {
    is => 'Genome::Utility::IO::Writer',
};

sub write_one {
    my ($self, $classification) = @_;

    $self->output->print($classification->get_name.';');
    $self->output->print(($classification->is_complemented ? '-' : ' ').';');

    my $taxon = $classification->get_taxa;
    for my $taxon ( $classification->get_taxa ) {
        $self->_print_taxon_id_and_confidence($taxon);
    }

    $self->output->print("\n");

    return 1;
}

sub _print_taxon_id_and_confidence {
    $_[0]->output->print(
        sprintf(
            '%s:%s;',
            $_[1]->id,
            ($_[1]->get_tag_values('confidence'))[0],
        )
    );
}

1;

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

