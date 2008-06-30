package Genome::Model::Tools::Newbler::NewAssembly;

use strict;
use warnings;

class Genome::Model::Tools::Newbler::NewAssembly {
    is => 'Genome::Model::Tools::Newbler',
    has => [
            dir => {
                    is => 'String',
                    doc => 'pathname of the output directory',
                },
        ],

};

sub help_brief {
"genome-model tools newbler new-assembly --dir=DIR";
}

sub help_detail {
    return <<"EOS"

EOS
}

sub execute {
    my $self = shift;

    $DB::single=1;
    my $cmd = $self->full_bin_path('createProject') .' -t asm '. $self->dir;
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return status from command '$cmd'");
        return
    }
    return 1;
}

1;

