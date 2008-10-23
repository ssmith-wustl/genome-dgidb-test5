package Genome::Model::Tools::WuBlast::Blastn;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::WuBlast::Blastn {
    is => 'Genome::Model::Tools::WuBlast',
    has => [
            database => {
                         is => 'String',
                         is_input => 1,
                         doc => 'the path to a blastable database(xdformat)',
                     },
            query_file => {
                           is => 'String',
                           is_input => 1,
                           doc => 'the path to the query file',
                       },
    ],
    has_optional => [
                     blast_params => {
                                      is => 'String',
                                      is_param => 1,
                                      doc => 'a set of parameters to use with blast',
                                  },
                 ],
};

sub help_brief {
    "a genome-model tool for executing a nucleotide wu-blast alignment",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt wu-blast blastn ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my $verify_database = Genome::Model::Tools::WuBlast::Xdformat::Verify->execute(database => $self->database);
    unless ($verify_database) {
        $self->error_message('Failed to verify xdb blastable database '. $self->database);
        return;
    }

    my $params = $self->blast_params || '';
    my $cmd = 'blastn '. $self->database .' '. $self->query_files .' '. $params;
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command '$cmd'");
        return;
    }
    return 1;
}

1;

