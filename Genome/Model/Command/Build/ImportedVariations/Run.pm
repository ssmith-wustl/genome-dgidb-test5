package Genome::Model::Command::Build::ImportedVariations::Run;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ImportedVariations::Run {
    is => 'Genome::Model::Event',
 };

$Workflow::Simple::override_lsf_use=1;

sub sub_command_sort_position { 41 }

sub help_brief {
    "Build for imported annotation  models (not implemented yet => no op)"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported annotation database
EOS
}

sub execute {
    my $self = shift;
    $self->status_message("This build is a no-op! Created Successfully");
    return 1;
}

1;
