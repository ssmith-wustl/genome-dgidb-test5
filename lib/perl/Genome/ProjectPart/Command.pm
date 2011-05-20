package Genome::ProjectPart::Command;

use strict;
use warnings;

use Genome;

class Genome::ProjectPart::Command {
    is => 'Command',
    is_abstract => 1,
    doc => 'work with ProjectParts',
};

sub is_sub_command_delegator { return 1; }

Genome::Command::Crud->init_sub_commands(
    target_class => 'Genome::ProjectPart',
    target_name => 'project-part',
    list => { show => 'project_id,entity_class_name,entity_id,label,role' },
    update => { only_if_null => 1, },
    delete => { do_not_init => 1, },
);

1;


