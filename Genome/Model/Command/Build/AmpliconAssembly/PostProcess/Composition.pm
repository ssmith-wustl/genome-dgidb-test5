package Genome::Model::Command::Build::AmpliconAssembly::PostProcess::Composition;

use strict;
use warnings;

use Genome;

use Genome::Model::Tools::MetagenomicClassifier::Rdp;

class Genome::Model::Command::Build::AmpliconAssembly::PostProcess::Composition {
    is => 'Genome::Model::Command::Build::AmpliconAssembly::PostProcess',
};

#< Beef >#
sub execute {
    my $self = shift;

    unlink $self->model->rdp_file if -e $self->model->rdp_file;
        
    my $classifier = Genome::Model::Tools::MetagenomicClassifier::Rdp->create(
        input_file => $self->model->assembly_fasta,
        output_file => $self->model->rdp_file,
    )
        or return;
    my $classification = $classifier->execute
        or return;

    return 1 if -s $self->model->rdp_file;

    $self->error_message("RDP classification executed correctly, but a file was not created");
    return;
}

1;

#$HeadURL$
#$Id$
