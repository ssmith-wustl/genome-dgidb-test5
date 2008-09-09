package Genome::Model::Tools::454;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Tools::454 {
    is => ['Command'],
    has => [
            arch_os => {
                        calculate => q|
                            my $arch_os = `uname -m`;
                            chomp($arch_os);
                            return $arch_os;
                        |
                    },
        ]
};

sub help_brief {
    "tools to work with 454 reads"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS

EOS
}

sub bin_path {
    my $self = shift;

    my $base_path = '/gsc/pkg/bio/454/installed';
    my $tail;
    if ($self->arch_os =~ /64/) {
        $tail = '-64/bin';
    } else {
        $tail = '/bin';
    }
    return $base_path . $tail;
}

1;

