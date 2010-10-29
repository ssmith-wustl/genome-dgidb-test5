package Genome::Model::DeNovoAssembly::Command; 

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::DeNovoAssembly::Command {
    is => 'Command',
    is_abstract => 1,
};

#< Help >#
sub help_brief {
    return 'Operate on de novo assembly models/builds';
}

sub help_detail {
    return help_brief();
}
#<>#

#< Command Stuff >#
sub sub_command_category { 'type specific' }

sub _command_name_brief {
    return 'de-novo-assembly';
}
#<>#

1;

#$HeadURL$
#$Id$
