package Genome::Model::Tools::Novocraft;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::Novocraft {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => '0.6.3', doc => "Version of novocraft to use" },
        arch_os => {
                    calculate => q|
                            my $arch_os = `uname -m`;
                            chomp($arch_os);
                            return $arch_os;
                        |
                },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run novocraft or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools novocraft ...    
EOS
}

sub help_detail {                           
    return <<EOS 
More information about the novocraft suite of tools can be found at http://novocraft.sourceforege.net.
EOS
}

sub novocraft_path {
    my $self = $_[0];
    return $self->path_for_novocraft_version($self->use_version);
}
my %NOVOCRAFT_VERSIONS = (
                    '2.03.12' => '/gsc/pkg/bio/novocraft/novocraft-2.03.12/novoalign',
                    'novocraft'   => 'novoalign',
                );

sub available_novocraft_versions {
    my $self = shift;
    return keys %NOVOCRAFT_VERSIONS;
}

sub path_for_novocraft_version {
    my $class = shift;
    my $version = shift;

    if (defined $NOVOCRAFT_VERSIONS{$version}) {
        return $NOVOCRAFT_VERSIONS{$version};
    }
    die('No path for novocraft version '. $version);
}


1;

