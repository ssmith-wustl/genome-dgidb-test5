package Genome::Model::Tools::Newbler::RemoveRun;

use strict;
use warnings;

class Genome::Model::Tools::Newbler::RemoveRun {
    is => 'Genome::Model::Tools::Newbler',
    has => [
            dir => {
                    is => 'String',
                    doc => 'pathname of the output directory for project',
                },
            runs => {
                       is => 'array',
                       doc => 'a list of sff files, directories, or fasta files',
                   },
        ],

};

sub help_brief {
"genome-model tools newbler add-run --dir=DIR --inputs='FileA FileB'";
}

sub help_detail {
    return <<"EOS"

EOS
}

sub execute {
    my $self = shift;

    $DB::single=1;
    my $cmd = $self->full_bin_path('removeRun') .' '. $self->dir .' '. join(' ',@{$self->runs});
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return status from command '$cmd'");
        return
    }
    return 1;
}

1;

