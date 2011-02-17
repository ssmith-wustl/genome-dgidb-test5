package Genome::Library::Command;

use strict;
use warnings;

use Genome;
      
class Genome::Library::Command {
    is => 'Command',
    is_abstract => 1,
    doc => 'work with libraries',
};

use Genome::Command::Crud;
Genome::Command::Crud->init_sub_commands(
    target_class => 'Genome::Library',
    target_name => 'libraries',
    list => { show => 'id,name,sample_id', },
    update => { only_if_null => 1, },
    delete => { do_not_init => 1, },
);

1;

