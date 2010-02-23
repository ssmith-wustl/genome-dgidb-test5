package Genome::Model::Tools::Cmds::CallR;

use warnings;
use strict;
use Genome;
use Cwd;
use Statistics::R;
require Genome::Utility::FileSystem;

class Genome::Model::Tools::Cmds::CallR {
    is => 'Command',
    has => [
    command => {
        type => 'String',
        is_optional => 0,
        doc => 'R command to be run in temp directory using this script',
    },
    ]
};

sub help_brief {
    "Wrapper to call functions in R library."
}
sub help_detail {
    "Wrapper to call functions in R library."
}

sub execute {
    my $self = shift;
    my $command = $self->command;
    my $r_library = __FILE__ . ".cmds_lib.R"; 
    
    my $tempdir = Genome::Utility::FileSystem->create_temp_directory();
    my $cwd = cwd();
    my $R = Statistics::R->new(tmp_dir => $tempdir);
    $R->startR();
    $R->send("source('$r_library');");
    $R->send($command);
    $R->stopR();
    chdir $cwd;
}

