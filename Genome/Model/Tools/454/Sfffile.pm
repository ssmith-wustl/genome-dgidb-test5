package Genome::Model::Tools::454::Sfffile;

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::454;

class Genome::Model::Tools::454::Sfffile {
    is => ['Genome::Model::Tools::454'],
    has => [
            in_sff_file => {
                         doc => 'The sff file to operate',
                         is => 'string',
                     },
            out_sff_file => {
                            is => 'string',
                            doc => 'The output file path',
                        },
            params => {
                       is => 'string',
                       doc => 'The params to pass to sfffile',
                   },
        ],
};

sub help_brief {
    "constructs a single SFF file containing the reads from a list of SFF files and/or 454 runs"
}

sub help_detail {
    return <<EOS
see 'sfffile' usage for valid params
EOS
}

sub execute {
    my $self = shift;

    my $params = $self->params .' -o '. $self->out_sff_file;
    my $cmd = $self->bin_path .'/sfffile '. $params .' '. $self->in_sff_file;
    print 'Running: '. $cmd ."\n";
    
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero exit code '$rv' returned by sffinfo");
        return;
    }
    return 1;
}

1;


