package Genome::Model::Command::AddReads::ProcessLowQualityAlignments::BlatPlusCrossmatch;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::ProcessLowQualityAlignments::BlatPlusCrossmatch {
    is => 'Genome::Model::Command::AddReads::ProcessLowQualityAlignments',
    has => [
            blat_output => {via => 'prior_event'},
        ]
};

sub help_brief {
    "Not sure yet but might use cross_match to align unplaced reads from blat alignments";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads process-low-quality-alignments blat-plus-crossmatch --model-id 5 --read-set-id 10
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

    $self->error_message('Not Implemented: '. $self->command_name .' on '. $model->name);

    return 0;
}


sub verify_successful_completion {
    my $self = shift;

    return 1;
}

1;

