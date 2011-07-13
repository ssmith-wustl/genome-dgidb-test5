package Genome::Model::Tools::Joinx;

use strict;
use warnings;

use Genome;
use Carp qw/confess/;

my $DEFAULT_VER = '1.2';

class Genome::Model::Tools::Joinx {
    is  => 'Command',
    is_abstract => 1,
    has_input => [
        use_version => {
            is  => 'Version', 
            doc => "joinx version to be used.  default_value='$DEFAULT_VER'",
            is_optional   => 1, 
            default_value => $DEFAULT_VER,
        },
    ],
};


sub help_brief {
    "Tools to run joinx, a variant file manipulation tool.";
}

sub help_synopsis {
    "gmt joinx ...";
}

sub help_detail {                           
    "used to invoke joinx commands";
}

sub joinx_path {
    my $self = shift;
    my $ver = $self->use_version || "";
    my $path = "/usr/bin/joinx$ver";
    if (! -x $path) {
        confess "Failed to find executable joinx version $ver at $path!";
    }
    return $path;
}



1;

