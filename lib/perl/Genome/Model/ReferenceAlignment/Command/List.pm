package Genome::Model::ReferenceAlignment::Command::List;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::ReferenceAlignment::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Model::ReferenceAlignment' 
        },
        show => { default_value => 'id,name,subject_name,reference_sequence_buid_id,processing_profile_name' },
    ],
    doc => 'list genome models',
};

sub sub_command_sort_position { 3 }

sub Xhelp_brief { shift->__meta__->doc }

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/List.pm $
#$Id: List.pm 40876 2008-11-11 22:48:58Z ebelter $
