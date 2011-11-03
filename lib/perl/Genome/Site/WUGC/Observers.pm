package Genome::Site::WUGC::Observers;

use strict;
use warnings;

use Genome::Site::WUGC::Observers::ModelGroup;
use Genome::Site::WUGC::Observers::Project;
use Genome::Site::WUGC::Observers::Command;

UR::Object::Type->add_observer(
    aspect => 'load',
    callback => sub {
        my $meta = shift;
        my $class_name = $meta->class_name;
        if ($class_name eq 'Genome::ModelGroup') {
            eval "use Genome::Site::WUGC::Observers::ModelGroup;";
        } elsif ($class_name eq 'Genome::Project') {
            eval "use Genome::Site::WUGC::Observers::Project;";
        }
    },
);

1;

