package Genome::Model::Command::AddReads::UpdateGenotypeProbabilities::Maq;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
);

sub help_brief {
    "Use maq to build the mapping assembly"
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub execute {
    my $self = shift;

    my $model = Genome::Model->get(id => $self->model_id);

    my $working_dir = $self->resolve_run_directory;

    # Make sure the output directory exists
    unless (-d $working_dir) {
        $self->error_message("working directory $working_dir does not exist, please run assign-run first");
        return;
    }

    my $accumulated_alignments_file = $working_dir . '/alignments_run_' . $self->run_name;
    unless (-f $accumulated_alignments_file) {
        $self->error_message("Alignments file $accumulated_alignments_file was not found.  It should have been created by a prior run of align-reads maq");
        return;
    }

    my $assembly_output_file = sprintf('%s/assembly_%s.cns', $working_dir, $self->run_name);
    my $ref_seq_file = $model->reference_sequence_file;

    my $assembly_opts = $model->genotyper_params;
    system("maq assemble $assembly_opts $assembly_output_file $ref_seq_file $accumulated_alignments_file");
}

1;

