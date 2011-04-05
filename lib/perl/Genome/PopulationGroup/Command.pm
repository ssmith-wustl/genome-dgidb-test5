package Genome::PopulationGroup::Command;

use strict;
use warnings;

use Genome;
      
class Genome::PopulationGroup::Command {
    is => 'Command',
    is_abstract => 1,
    doc => 'work with population groups',
};

sub is_sub_command_delegator { return 1; }

use Genome::Command::Crud;
Genome::Command::Crud->init_sub_commands(
    target_class => 'Genome::PopulationGroup',
    target_name => 'population group',
    list => { show => 'id,name,description', },
    update => { only_if_null => 1, },
    delete => { do_not_init => 1, },
);

1;

