package Genome::Model::Tools::AmpliconAssembly::Orient;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::AmpliconAssembly::Orient {
    is => 'Genome::Model::Tools::AmpliconAssembly',
};

sub execute {
    my $self = shift;

    my $amplicons = $self->get_amplicons
        or return;

    for my $amplicon ( @$amplicons ) {
        my $bioseq = $amplicon->get_bioseq;
        next unless $bioseq; # ok - not all will have a bioseq

        my $classification = $amplicon->get_classification;
        unless ( $classification ) {
            $self->error_message(
                sprintf(
                    'Can\'t get classification for amplicon (%s)', 
                    $amplicon->get_name,
                )
            );
            next;
        }

        $amplicon->confirm_orientation( $classification->is_complemented )
            or return;
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
