package Genome::Model::ProteinAnnotation::Command::Annotator;

use strict;
use warnings;
use Genome;

class Genome::Model::ProteinAnnotation::Command::Annotator {
    is => 'Command::V2',
    is_abstract => 1,
    has => [
        version     => { is => 'Text', is_input => 1 },
        output_dir  => { is => 'FilesystemPath', is_input => 1, is_output => 1, },
    ],
    doc => 'annotator abstract base class',
};

sub name { 
    my $self = shift;
    my $name = $self->command_name_brief;
    return $name;
}

sub requires_chunking { die "override requires_chunking() to return 1 or 0 in " . shift }

sub sub_command_category { 'annotators' }

sub help_brief {
    return 'run the ' . shift->name . ' protein annotator'
}

1;

