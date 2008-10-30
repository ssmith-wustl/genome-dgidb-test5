package Genome::Model::Command::MetaGenomicComposition::OrientAssembledFasta;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Genome::Model::Tools::Fasta::Orient;

class Genome::Model::Command::MetaGenomicComposition::OrientAssembledFasta {
    is => 'Genome::Model::Command::MetaGenomicComposition',
};

sub execute {
    my $self = shift;

    my $assembled_fasta = $self->model->all_assembled_fasta;
    my $sense_primer_fasta = $self->model->sense_primers_fasta_file;
    my $anti_sense_primer_fasta = $self->model->anti_sense_primers_fasta_file;

    my $orient = Genome::Model::Tools::Fasta::Orient->create(
        fasta_file => $assembled_fasta,
        sense_fasta_file => $sense_primer_fasta,
        anti_sense_fasta_file => $anti_sense_primer_fasta,
    )
        or return;
    $orient->execute
        or return;

    return 1;
}

1;

=pod

=head1 Name

Modulesubclone

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

