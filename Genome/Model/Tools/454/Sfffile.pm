package Genome::Model::Tools::454::Sfffile;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::454::Sfffile {
    is => ['Genome::Model::Tools::454'],
    has => [
            in_sff_files => {
                            doc => 'The sff file to operate',
                            is => 'string',
                            is_many => 1,
                     },
            out_sff_file => {
                            is => 'string',
                            doc => 'The output file path',
                        },
            params => {
                       is => 'string',
                       doc => 'The params to pass to sfffile',
                       is_optional => 1,
		   },
	    assembler_version => {
		                  is => 'string',
				  doc => 'newbler assembler version',
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

    my $params = $self->params || '';
    $params .= ' -o '. $self->out_sff_file;
    my $cmd = $self->bin_path .'/sfffile '. $params .' '. join(' ',$self->in_sff_files);
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero exit code '$rv' returned by sffinfo");
        return;
    }
    return 1;
}

1;


