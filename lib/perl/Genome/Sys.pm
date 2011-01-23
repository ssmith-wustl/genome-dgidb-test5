package Genome::Sys;

use strict;
use warnings;
use Genome;
use Cwd;

class Genome::Sys { 
    is => 'UR::Singleton', 
};

sub dbpath {
    my ($class, $name, $version) = @_;
    unless ($version) {
        die "Genome::Sys dbpath must be called with a database name and a version.  Use 'latest' for the latest installed version.";
    }
    my $base_dirs = $ENV{"GENOME_DB"} ||= '/var/lib/genome/db';
    return $class->_find_in_path($base_dirs, "$name/$version");
}

sub swpath {
    my ($class, $name, $version) = @_;
    unless ($version) {
        die "Genome::Sys swpath must be called with a database name and a version.  Use 'latest' for the latest installed version.";
    }
    my $base = $ENV{"GENOME_SW"} ||= '/var/lib/genome/sw';
    return join("/",$base,$name,$version);
}

sub _find_in_path {
    my ($class, $base_dirs, $subdir) = @_;
    my @base_dirs = split(':',$base_dirs);
    my @dirs =
        map { -l $_ ? Cwd::abs_path($_) : ($_) }
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

# until we get the above into ur...

=pod

=head1 NAME

Genome::Sys

=head1 VERSION

This document describes Genome::Sys version 0.05.

=head1 SYNOPSIS

use Genome;

my $dir = Genome::Sys->dbpath('cosmic', 'latest');

=head1 DESCRIPTION

Genome::Sys is a simple layer on top of OS-level concerns,
including those automatically handled by the analysis system, 
like database cache locations.

=head1 METHODS

=head2 swpath($name,$version)

Return the path to a given executable, library, or package.

This is a wrapper for the OS-specific strategy for managing multiple versions of software packages,
(i.e. /etc/alternatives for Debian/Ubuntu)

The GENOME_SW environment variable contains a colon-separated lists of paths which this falls back to.
The default value is /var/lib/genome/sw/.


=head2 dbpath($name,$version)

Return the path to the preprocessed copy of the specified database.
(This is in lieu of a consistent API for the database in question.)

The GENOME_DB environment variable contains a colon-separated lists of paths which this falls back to.
The default value is /var/lib/genome/db/.

=cut
