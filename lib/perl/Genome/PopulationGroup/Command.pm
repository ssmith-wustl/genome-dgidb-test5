package Genome::PopulationGroup::Command;

use strict;
use warnings;

use Genome;
      
class Genome::PopulationGroup::Command {
    is => 'Command::Tree',
    doc => 'Work with population groups',
};

use Genome::Command::Crud;
Genome::Command::Crud->init_sub_commands(
    target_class => 'Genome::PopulationGroup',
    target_name => 'population group',
    list => { show => 'id,name,description', },
    update => { only_if_null => 1, },
    delete => { do_not_init => 1, },
);

1;

