package MGAP::Command::BuildGlimmerInput;

use strict;
use warnings;

use Workflow;

class MGAP::Command::BuildGlimmerInput {
    is => ['MGAP::Command'],
    has => [
        fasta_files => { is => 'ARRAY', doc => 'array of fasta file names' },
        model_file => { is => 'SCALAR', doc => 'absolute path to the model file for this fasta' },
        pwm_file => { is => 'SCALAR' , doc => 'absolute path to the pwm file for this fasta' }
    ],
};

operation MGAP::Command::BuildGlimmerInput {
    input  => [ 'fasta_files' ],
    output => [ 'model_file', 'pwm_file' ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;


    1;
}
 
1;
