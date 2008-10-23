package Genome::Model::Tools::WuBlast::Xdformat::Verify;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::WuBlast::Xdformat::Verify {
    is => 'Genome::Model::Tools::WuBlast::Xdformat',
    has => [
            database => {
                         is => 'String',
                         is_input => 1,
                         doc => 'the path to a new or existing database',
                     },
        ],
};

sub help_brief {
    "a genome-model tool for verifying a nucleotide wu-blastable database",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt wu-blast xdformat verify --database --fasta-files
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my $cmd = 'xdformat -n -V '. $self->database;
    $self->status_message('Running: '. $cmd);
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command '$cmd'");
        return;
    }
    return 1;
}

1;

