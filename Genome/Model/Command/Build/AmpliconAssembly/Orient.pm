package Genome::Model::Command::Build::AmpliconAssembly::Orient;

use strict;
use warnings;

use Genome;

require Genome::Model::Tools::Fasta::Orient;

class Genome::Model::Command::Build::AmpliconAssembly::Orient {
    is => 'Genome::Model::Event',
};

#< Subclassing...don't >#
sub _get_sub_command_class_name {
  return __PACKAGE__;
}

#< LSF >#
sub bsub_rusage {
    return "";
}

#< The Beef >#
sub execute {
    my $self = shift;

    unless ( -s $self->model->assembly_fasta ) {
        $self->error_message(
            sprintf(
                "The assembly fasta file for model (<id> %s <name> %s) does not exist.  Please collate it first.",
                $self->model->id,
                $self->model->name,
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
        fasta_file => $self->model->assembly_fasta,
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
