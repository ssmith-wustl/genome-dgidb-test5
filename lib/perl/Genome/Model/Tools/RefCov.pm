package Genome::Model::Tools::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov {
    is => ['Command'],
    has => [
        alignment_file_path => {
            is => 'String',
            doc => 'The path to the alignment file path.',
        },
        alignment_file_format => {
            is => 'String',
            doc => 'The format of the alignment file.',
            default_value => 'bam',
            valid_values => ['bam'],
        },
        roi_file_path => {
            is => 'String',
            doc => 'The format of the region-of-interest file.',
        },
        roi_file_format => {
            is => 'String',
            doc => 'The format of the region-of-interest file.',
            default_value => 'bed',
            valid_values => ['bed'],
        },
    ],
};
sub help_brief {
    "Tools to run the Ref-Cov tookit.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt ref-cov ...    
EOS
}

sub help_detail {
    return <<EOS 
Please add help detail!
EOS
}


1;
