package Genome::Model::Tools::UpdateTabCompletion;

use strict;
use warnings;

class Genome::Model::Tools::UpdateTabCompletion {
    is => 'Genome::Command::Base',
    doc => 'update the tab completion spec files (.opts)',
};

sub execute {
    my $self = shift;

    my $classname;
    $classname = 'Genome::Model::Tools' if ($self->command_name =~ /^gmt/);
    $classname = 'Genome::Command' if ($self->command_name =~ /^genome/);

    unless ($classname) {
        $self->error_message("Unable to determine class to generate .opts file for.");
        return;
    }

    my $genome_completion = UR::Namespace::Command::CreateCompletionSpecFile->create(
        classname => $classname,
    );
    unless ($genome_completion->execute) {
        $self->error_message("Updating the genome command spec file did not complete succesfully!");
    }

    $self->status_message("Remember to commit the updated .opts file(s)!");

    return 1;
}

1;
