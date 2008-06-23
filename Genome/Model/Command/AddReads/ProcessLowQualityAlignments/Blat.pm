package Genome::Model::Command::AddReads::ProcessLowQualityAlignments::Blat;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::ProcessLowQualityAlignments::Blat {
    is => 'Genome::Model::Command::AddReads::ProcessLowQualityAlignments',
    has => [
            alignment_file => {via => 'prior_event'},
        ]
};

sub help_brief {
    "Not sure yet";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads process-low-quality-alignments blat --model-id 5 --read-set-id 10
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
    $self->status_message('Not Implemented: '. $self->command_name .' on '. $model->name);
    return 1;
}


1;

