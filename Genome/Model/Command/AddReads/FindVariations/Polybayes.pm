package Genome::Model::Command::AddReads::FindVariations::Polybayes;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;

class Genome::Model::Command::AddReads::FindVariations::Polybayes {
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments identify-variation polybayes --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the postprocess-alignments process
EOS
}

sub execute {
    my $self = shift;
    my $model = Genome::Model->get(name=>$self->model);
    $self->error_message("running " . $self->command_name . " on " . $model->name . "!");
    $self->status_message("Model Info:\n" . $model->pretty_print_text);
    return 0; 
}
1;

