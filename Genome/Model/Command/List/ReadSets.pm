#!/gsc/bin/perl

package Genome::Model::Command::List::ReadSets;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::List::ReadSets {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => { is_constant => 1, value => 'Genome::RunChunk' },
        model               => { is_optional => 1 },
        show                => { default_value => 'run_name,subset_name,sample_name,sequencing_platform,is_paired_end' },
    ]    
};

sub sub_command_sort_position {  }

sub help_brief {
    'list availale reads by "set": i.e. solexa lane, 454 region, etc..'
}
sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS 
EOS
}

1;
