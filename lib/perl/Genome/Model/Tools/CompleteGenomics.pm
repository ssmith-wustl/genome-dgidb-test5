package Genome::Model::Tools::CompleteGenomics;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::CompleteGenomics {
    is => 'Command::V2',
};

sub path_to_cgatools {
    my $self = shift;

    #if/when versioning support added, just change this here
    return '/gsc/bin/cgatools';
}

sub run_command {
    my $self = shift;
    my $subcommand = shift;
    my %shellcmd_opts = @_;

    Genome::Sys->shellcmd(
        cmd => join(' ', $self->path_to_cgatools, $subcommand),
        %shellcmd_opts,
    );

    return 1;
}

1;
