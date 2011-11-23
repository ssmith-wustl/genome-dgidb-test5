package Genome::Model::Tools::Allpaths::DeNovoAssemble;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Allpaths::DeNovoAssemble {
    is => 'Genome::Model::Tools::Allpaths::Base',
    has => [
        output_dir => {
            is => 'Text',
            doc => 'The output directory.' 
        },
    ],
};

sub help_brief {
    'run ALLPATHS de novo assembler';
}

sub help_detail {
    return;
}

sub execute {
    my $self = shift;

    $self->error_message("Not ready!");
    return;

    my $output_dir = $self->output_dir;
    if ( not $output_dir or not -d $output_dir ) {
        $self->error_message("No output directory given!");
        return;
    }

    # Need group file
    # Need library file
    # Prepare
    # -need group file
    # -need library file
    # -sep by library
    # -must be at least 2 paired libs, one short, one long
    # -may have add'l long frag lib

    # Set ulimit to 100000
    my $ulimit;
    my $ulimit_cmd;

    #required params
    my $cmd = 'RunAllPathsLG '.join(' ', map { $_.'='.$output_dir } (qw/ RUN /));

    $self->status_message("Run ALLPTAHS de novo");
    my $rv = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
    if ( not $rv ) {
        $self->error_message("Failed to run ALLPATHS de novo: $@");
        return;
    }
    $self->status_message("Run ALLPTAHS de novo...OK");

    return 1;
}

1;

