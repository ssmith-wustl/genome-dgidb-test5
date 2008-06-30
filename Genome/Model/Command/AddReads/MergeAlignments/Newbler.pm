package Genome::Model::Command::AddReads::MergeAlignments::Newbler;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;


class Genome::Model::Command::AddReads::MergeAlignments::Newbler {
    is => [
           'Genome::Model::Command::AddReads::MergeAlignments',
       ],
    has => [   ],
};

sub help_brief {
    "run one last round of newbler alignment and output consensus";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads postprocess-alignments merge-alignments newbler --model-id 5 --ref-seq-id all_sequences
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
    my $model = $self->model;
    my $alignments_directory = $model->alignments_directory;
    my $run_project = Genome::Model::Tools::Newbler::RunProject->create(
                                                                        dir => $alignments_directory,
                                                                    );
    unless ($run_project->execute) {
        $self->error_message('Failed to run last pass of mapping');
        return;
    }
    return 1;
}

1;

