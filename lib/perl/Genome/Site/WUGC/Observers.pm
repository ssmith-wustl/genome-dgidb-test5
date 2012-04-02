package Genome::Site::WUGC::Observers;

use strict;
use warnings;

UR::Object::Type->add_observer(
    aspect => 'load',
    callback => sub {
        my $meta = shift;
        my $class_name = $meta->class_name;
        if ($class_name eq 'Genome::ModelGroup') {
            require Genome::Site::WUGC::Observers::ModelGroup;
        } elsif ($class_name eq 'Genome::Project') {
            require Genome::Site::WUGC::Observers::Project;
        } elsif ($class_name eq 'Command::V1') {
            require Genome::Site::WUGC::Observers::Command;
        } elsif ($class_name eq 'Genome::DataSource::GMSchema') {
            require Genome::Site::WUGC::Observers::GMSchema;
        }
        die $@ if $@;
    },
);

1;

