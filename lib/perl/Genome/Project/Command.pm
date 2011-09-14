package Genome::Project::Command;

use strict;
use warnings;

use Genome;

class Genome::Project::Command {
    is => 'Command::Tree',
    doc => 'Work with projects',
};

Genome::Command::Crud->init_sub_commands(
    target_class => 'Genome::Project',
    target_name => 'project',
    list => { show => 'id,name' },
    update => { only_if_null => 1, },
    delete => { do_not_init => 1, },
);

1;


