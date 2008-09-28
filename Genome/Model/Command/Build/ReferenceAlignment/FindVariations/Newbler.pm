package Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Newbler;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;

class Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Newbler {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::FindVariations',
       ],
    has => [  ],

};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments identify-variation newbler --model-id 5 --ref-seq-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the postprocess-alignments process
EOS
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    $self->status_message('Not Implemented: ' . $self->command_name . ' on ' . $model->name);
    return 1;
}


1;

