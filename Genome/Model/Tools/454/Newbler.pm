package Genome::Model::Tools::454::Newbler;

use strict;
use warnings;

use above "Genome";

use File::Basename;

class Genome::Model::Tools::454::Newbler {
    is => ['Genome::Model::Tools::454'],
    has => [
            test => {
                     is => 'Boolean',
                     doc => 'A flag to use the test version of newbler',
                     default_value => 0,
                 },
        ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run newbler or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools newbler ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub newbler_bin {
    my $self = shift;

    my $bin_path = $self->bin_path;
    if ($self->test) {
        if ($self->arch_os =~ /64/) {
            $bin_path = '/gsc/pkg/bio/454/newbler/applicationsBin64';
        } else {
            $bin_path = '/gsc/pkg/bio/454/newbler/applicationsBin32';
        }
    }
    return $bin_path;
}

sub full_bin_path {
    my $self = shift;
    my $cmd = shift;

    return $self->newbler_bin .'/'. $cmd;
}



1;

