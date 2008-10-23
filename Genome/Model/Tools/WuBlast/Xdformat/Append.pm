package Genome::Model::Tools::WuBlast::Xdformat::Append;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::WuBlast::Xdformat::Append {
    is => 'Genome::Model::Tools::WuBlast::Xdformat',
    has => [
            database => {
                         is => 'String',
                         is_input => 1,
                         doc => 'the path to a new or existing database',
                     },
        ],
    has_many => [
            fasta_files => {
                            is => 'String',
                            is_input => 1,
                            doc => 'a list of paths to fasta sequence files',
                        },
             ],
};

sub help_brief {
    "a genome-model tool for creating a nucleotide wu-blastable database",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt wu-blast xdformat append --database --fasta-files
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my $verify = Genome::Model::Tools::WuBlast::Xdformat::Verify->execute(database => $self->database);
    unless ($verify) {
        $self->error_message('Failed to verify xdb database'. $self->database);
        return;
    }
    my $cmd = 'xdformat -n -a '. $self->database .' '. join(' ',$self->fasta_files);
    $self->status_message('Running: '. $cmd);
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command '$cmd'");
        return;
    }
    return 1;
}

1;

