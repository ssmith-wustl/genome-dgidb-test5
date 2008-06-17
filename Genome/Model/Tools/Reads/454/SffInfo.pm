package Genome::Model::Tools::Reads::454::SffInfo;

use strict;
use warnings;

use above "Genome";
use Command;

class Genome::Model::Tools::Reads::454::SffInfo {
    is => 'Command',
    has => [
            sff_file => {
                         doc => 'The sff file to operate',
                         is => 'string',
                     },
            output_file => {
                            is => 'string',
                            doc => 'The output file path',
                        },
            params => {
                       is => 'string',
                       doc => 'The params to pass to sffinfo',
                   },
        ],
};

sub help_brief {
    "convert sff file to fasta file"
}

sub help_detail {
    return <<EOS
convert sff file to fasta file
EOS
}

sub execute {
    my $self = shift;

    my $cmd = 'sffinfo '. $self->params .' '. $self->sff_file .' > '. $self->output_file;
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero exit code '$rv' returned by sffinfo");
        return;
    }
    return 1;
}

1;


