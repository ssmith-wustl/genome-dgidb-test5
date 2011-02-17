
package Genome::Model::Tools::Galaxy::Update;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Galaxy::Update {
    is  => 'Command',
    has => [
        path => {
            is  => 'String',
            is_optional => 1,
            doc => 'Galaxy setup path'
        },
        pull => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'Update Galaxy software',
            default => 1
        }
    ]
};

sub execute {
    my $self = shift;

    my $path = $self->path;
    if (!defined($path)) {
        $path = $ENV{HOME} . "/galaxy/";
    }
    if ($self->pull) {
        # look for key files to make sure path is galaxy directory
        my @key_files = [".hg", "run_galaxy_listener.sh", "run.sh"];
        foreach my $k (@key_files) {
            my $file_path = $path . "/" . $k;
            unless (-e $file_path) {
                $self->warning_message("Does not appear to be valid galaxy folder");
                die();
            }
        }
    }
}

