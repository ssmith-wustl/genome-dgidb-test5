package Genome::Model::Command::AddReads::AlignReads::RunMapping;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use Genome::Model::Command::AddReads::AlignReads;
use Genome::Model::Tools::AlignReads::454;

class Genome::Model::Command::AddReads::AlignReads::RunMapping {
    is => [
        'Genome::Model::Command::AddReads::AlignReads',
    ],
    has => [
            sff_file => { via => "prior_event" },
        ],
};

sub help_brief {
    "Use blat plus crossmatch to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads blat-plus-crossmatch --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub should_bsub { 1;}

sub execute {
    my $self = shift;

    $DB::single = 1;
    my $model = $self->model;

    my $read_set = $self->read_set;

    my $ref_seq_path = $model->reference_sequence_path;

    my $aligner_params = $model->aligner_params || '';

    my $cmd = 'runMapping -o '. $self->read_set_directory .' '. $aligner_params .' '.
        $ref_seq_path .' '. $self->sff_file;

    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero exit code '$rv' from '$cmd'");
        return;
    }

    return 1;
}

sub verify_successful_completion {
    my ($self) = @_;

    return 1;
}



1;

