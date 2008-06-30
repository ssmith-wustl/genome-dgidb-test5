package Genome::Model::Tools::Newbler::RunProject;

use strict;
use warnings;

class Genome::Model::Tools::Newbler::RunProject {
    is => 'Genome::Model::Tools::Newbler',
    has => [
            dir => {
                    is => 'String',
                    doc => 'pathname of the output directory for project',
                },
        ],
    has_optional => [
                     options => {
                                 is => 'String',
                                 doc => 'command line options to pass to newbler',
                             },
                 ],

};

sub help_brief {
"genome-model tools newbler add-run --dir=DIR [--options='-r']";
}

sub help_detail {
    return <<"EOS"

EOS
}

sub execute {
    my $self = shift;

    $DB::single=1;
    my $options = $self->options || '';
    my $cmd = $self->full_bin_path('runProject') .' '. $options .' '. $self->dir;
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return status from command '$cmd'");
        return
    }
    return 1;
}

1;

