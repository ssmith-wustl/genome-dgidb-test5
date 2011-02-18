
package Genome::Model::Tools::Galaxy::Setup;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Galaxy::Setup {
    is  => 'Command',
    has => [
        path => {
            is  => 'String',
            is_optional => 1,
            doc => 'Galaxy setup path'
        }
    ]
};

sub execute {
    my $self = shift;

    my $path = $self->path;
    if (!defined($path)) {
        $path = $ENV{HOME} . "/galaxy/";
    }
    my $command = "hg clone https://bitbucket.org/galaxy/galaxy-dist $path";
    $self->status_message("Cloning galaxy from remote repository. This is a 200MB download and may take several minutes");
    system($command);
    unless ($? == 0) {
        $self->warning_message("Encountered non zero exit. Error encountered in cloning Galaxy");
        die();
    }
    $self->status_message("Galaxy has been copied to $path. Installing Genome commands.");
    my $update_command = Genome::Model::Tools::Galaxy::Update->create(
        path => $path,
        pull => 0
    );
    $update_command->execute();
    system($path . "/run.sh");
}

