package Genome::Sys;

use strict;
use warnings;
use Genome;

class Genome::Sys { 
    is => 'UR::Singleton', 

};

sub dbpath {
    my ($class, $name, $version) = @_;
    my $base_dirs = $ENV{"GENOME_DB"} ||= '/var/lib/genome/db';
    return $class->_find_in_path($base_dirs, "$name/$version");
}

sub swpath {
    my ($class, $name, $version) = @_;
    my $base = $ENV{"GENOME_SW"} ||= '/var/lib/genome/sw';
    return join("/",$base,$name,$version);
}

sub _find_in_path {
    my ($class, $base_dirs, $subdir) = @_;
    my @base_dirs = split(':',$base_dirs);
    my @dirs =
        map { -l $_ ? readlink($_) : ($_) }
        map {
            my $path = join("/",$_,$subdir);
            (-e $path ? ($path) : ())
        }
        @base_dirs;
    return $dirs[0];
}

1;

__END__

    methods => [
        dbpath => {
            takes => ['name','version'],
            uses => [],
            returns => 'FilesystemPath',
            doc => 'returns the path to a data set',
        },
        swpath => {
            takes => ['name','version'],
            uses => [],
            returns => 'FilesystemPath',
            doc => 'returns the path to an application installation',
        },
    ]
