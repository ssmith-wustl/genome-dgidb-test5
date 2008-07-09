package Genome::Model::Command::AddReads::AlignReads::Newbler;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use Genome::Model::Command::AddReads::AlignReads;

use Genome::Model::Tools::454::Newbler::AddRun;
use Genome::Model::Tools::454::Newbler::RunProject;

class Genome::Model::Command::AddReads::AlignReads::Newbler {
    is => [
        'Genome::Model::Command::AddReads::AlignReads',
    ],
    has => [
            sff_file => { via => "prior_event" },
        ],
};

sub help_brief {
    "Use newbler to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads newbler --model-id 5 --read-set-id 10
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

    my $add_run = Genome::Model::Tools::454::Newbler::AddRun->create(
                                                                dir => $model->alignments_directory,
                                                                inputs => $self->sff_file,
                                                            );
    unless ($add_run->execute) {
        $self->error_message('Could not addRun '. $self->sff_file .' to newbler project '. $model->alignments_directory);
        return;
    }

    my $run_project = Genome::Model::Tools::454::Newbler::RunProject->create(
                                                                        dir => $model->alignments_directory,
                                                                        options => $model->aligner_params,
                                                                    );
    unless ($run_project->execute) {
        $self->error_message('Could not runProject on newbler project '. $model->alignments_directory
                             .' with params '. $model->aligner_params);
        return;
    }
    return 1;
}


1;

