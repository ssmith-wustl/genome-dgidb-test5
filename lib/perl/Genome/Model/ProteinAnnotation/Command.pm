package Genome::Model::ProteinAnnotation::Command; 

use strict;
use warnings;

use Genome;

class Genome::Model::ProteinAnnotation::Command {
    is => 'Command::Tree',
    is_abstract => 1,
};

sub sub_command_category { 'type specific' }

sub _command_name_brief {
    return 'rna-seq';
}

1;

