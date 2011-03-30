package Genome::Model::Tools::Assembly::Ace::ReplaceXsNs;

use strict;
use warnings;

use Genome;

require Finishing::Assembly::Factory;
require Finishing::Assembly::ContigTools;

class Genome::Model::Tools::Assembly::Ace::ReplaceXsNs {
    is => 'Command',
    has => [
        acefile => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'Acefile to replace Xs and Ns',
        },
        output_acefile => {
            is => 'Text',
            is_optional => 1,
            shell_args_position => 2,
            doc => 'Output acefile name. Defaults to input acefile with .xns_replaced on the end',
        },
    ],
};

sub execute {
    my $self = shift;

    # Open assembly
    my $acefile = $self->acefile;
    eval{ Genome::Sys->validate_file_for_reading($acefile); };
    if ( $@ ) {
        $self->error_message("Can;t validate acefile: $@");
        return;
    }

    my $fo = Finishing::Assembly::Factory->connect('ace', $acefile);
    unless ( $fo ) {
        $self->error_message("Can't create assembly factory for acefile ($acefile)");
        return;
    }
    my $asm_obj = $fo->get_assembly;
    my $contigs = $asm_obj->contigs();

    # Contig tools and exporter
    my $ct = Finishing::Assembly::ContigTools->new;
    unless ( defined $self->output_acefile ) {
        $self->output_acefile( $self->acefile.'.xns_replaced' );
    }
    my $xport = Finishing::Assembly::Ace::Exporter->new(file => $self->output_acefile);

    # Go through contigs
    while ( my $contig = $contigs->next ) {
        $self->status_message("Processing contig: " . $contig->name . "\n");
        my $new_ctg = $ct->replace_xns($contig);
        $self->status_message("Exporting contig: " . $contig->name ."\n");
        $xport->export_contig(contig => $new_ctg);
    }
    $xport->close;

    $self->status_message("Wrote ace file: $acefile".'.xns_replaced'."\n");

    return 1;
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

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

