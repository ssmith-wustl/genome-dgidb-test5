package Genome::Model::Command::Build::AmpliconAssembly::Orient;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::AmpliconAssembly::Orient {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $amplicons = $self->build->get_amplicons
        or return;

    for my $amplicon ( @$amplicons ) {
        my $bioseq = $amplicon->get_bioseq;
        next unless $bioseq; # ok - not all will have a bioseq

        my $classification = $amplicon->get_classification;
        unless ( $classification ) {
            $self->error_message(
                sprintf(
                    'Can\'t get classification for amplicon (<Amplicon %s> <Build Id %s>)', 
                    $amplicon->get_name,
                    $self->build->id,
                )
            );
            next;
        }

        $amplicon->confirm_orientation( $classification->is_complemented )
            or return;
    }
    
    #print $self->build->data_directory."\n"; <STDIN>;
    
    return 1;
}

sub _execute {
    my $self = shift;

    unless ( -s $self->build->assembly_fasta ) {
        $self->error_message(
            sprintf(
                "The assembly fasta file for model's (<id> %s <name> %s) build (<ID> %s) does not exist.  Please collate it first.",
                $self->model->id,
                $self->model->name,
                $self->build->id,
            )
        );
        return;
    }

    my %primer_fastas;
    for my $type (qw/ sense anti_sense /) {
        my $method = sprintf('%s_primer_fasta', $type);
        my $fasta = $self->model->processing_profile->$method;
        next unless -s $fasta;
        $primer_fastas{ sprintf('%s_fasta_file', $type) } = $fasta;
    }

    unless ( %primer_fastas ) { # No primers fastas exist
        $self->error_message( 
            sprintf(
                'No primer fasta files found for model\'s (<id> %s <name> %s) processing profile (<id> %s <name> %s)',
                $self->model->processing_profile->id, 
                $self->model->processing_profile->id, 
                $self->model->id, 
                $self->model->name
            ) 
        );
        return;
    }

    my $orient = Genome::Model::Tools::Fasta::Orient->create(
        fasta_file => $self->build->assembly_fasta,
        %primer_fastas,
    )
        or return;
    $orient->execute
        or return;

    return 1;
}

1;

#$HeadURL$
#$Id$
