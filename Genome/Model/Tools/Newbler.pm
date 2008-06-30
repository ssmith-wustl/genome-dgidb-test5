package Genome::Model::Tools::Newbler;

use strict;
use warnings;

use above "Genome";

use File::Basename;

class Genome::Model::Tools::Newbler {
    is => 'Command',
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

    my $test = $self->test;

    my $base_path = '/gsc/pkg/bio/454/installed';
    if ($test) {
        $base_path = '/gsc/pkg/bio/454/newbler';
    }
    my $archos = `uname -a`;
    my $tail;
    if ($archos =~ /64/) {
        if ($test) {
            $tail = '64';
        } else {
            $tail = '-64/bin';
        }
    } else {
        if ($test) {
            $tail = '32';
        } else {
            $tail = '/bin';
        }
    }
    if ($test) {
        return $base_path .'/applicationsBin'. $tail;
    }
    return $base_path . $tail;
}

sub full_bin_path {
    my $self = shift;
    my $cmd = shift;

    return $self->newbler_bin .'/'. $cmd;
}



1;

