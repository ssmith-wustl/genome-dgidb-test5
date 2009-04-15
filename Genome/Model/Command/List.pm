package Genome::Model::Command::List;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::Command::List {
    is => 'UR::Object::Command::List',
    has => [
    subject_class_name  => {
        is_constant => 1, 
        value => 'Genome::Model' 
    },
    ],
};
#Genome::Model::Command::List->get_class_object->property_meta_for_name('show')->default_value('id,name,subject_name,processing_profile_name');

sub help_brief {
    return 'List models';
}

sub help_deatil {
    return help_brief();
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/List.pm $
#$Id: List.pm 40876 2008-11-11 22:48:58Z ebelter $
