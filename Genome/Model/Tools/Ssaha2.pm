package Genome::Model::Tools::Ssaha2;

use strict;
use warnings;

use Genome;
use File::Basename;


#declare a default version here
##########################################
my $DEFAULT = '0.5.7';

class Genome::Model::Tools::Ssaha2 {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => $DEFAULT, doc => "Version of ssaha2 to use, default is $DEFAULT" },
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
    "Tools to run SSAHA2 or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools ssaha2 ...    
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}


my %BWA_VERSIONS = (
	'0.4.2' => '/gscuser/boberkfe/ssaha2/path/to/bin',
    'ssaha2'   => 'ssaha2',
);


sub ssaha2_path {
    my $self = $_[0];
    return $self->path_for_ssaha2_version($self->use_version);
}

sub available_ssaha2_versions {
    my $self = shift;
    return keys %BWA_VERSIONS;
}

sub path_for_ssaha2_version {
    my $class = shift;
    my $version = shift;

    if (defined $BWA_VERSIONS{$version}) {
        return $BWA_VERSIONS{$version};
    }
    die('No path for ssaha2 version '. $version);
}

sub default_ssaha2_version {
    die "default samtools version: $DEFAULT is not valid" unless $BWA_VERSIONS{$DEFAULT};
    return $DEFAULT;
}
        

1;

