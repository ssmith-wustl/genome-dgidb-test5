package Genome::Sys;

use strict;
use warnings;
use Genome;
use Cwd;

class Genome::Sys { 
    # TODO: remove all cases of inheritance 
    #is => 'UR::Singleton', 
};

sub dbpath {
    my ($class, $name, $version) = @_;
    unless ($version) {
        die "Genome::Sys dbpath must be called with a database name and a version.  Use 'latest' for the latest installed version.";
    }
    my $base_dirs = $ENV{"GENOME_DB"} ||= '/var/lib/genome/db';
    my $path = $class->_find_in_path($base_dirs, "$name/$version");
    die "File not found: $base_dirs/$name/$version" if (! defined $path);
    return $path;
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

# temp file management

sub _temp_directory_prefix {
    my $self = shift;
    my $base = join("_", map { lc($_) } split('::',$self->class));
    return $base;
}

our $base_temp_directory;
sub base_temp_directory {
    my $self = shift;
    my $class = ref($self) || $self;
    my $template = shift;

    my $id;
    if (ref($self)) {
        return $self->{base_temp_directory} if $self->{base_temp_directory};
        $id = $self->id;
    }
    else {
        # work as a class method
        return $base_temp_directory if $base_temp_directory;
        $id = '';
    }

    unless ($template) {
        my $prefix = $self->_temp_directory_prefix();
        $prefix ||= $class;
        my $time = UR::Time->now;

        $time =~ s/[\s\: ]/_/g;
        $template = "/gm-$prefix-$time-$id-XXXX";
        $template =~ s/ /-/g;
    }

    # See if we're running under LSF and LSF gave us a directory that will be
    # auto-cleaned up when the job terminates
    my $tmp_location = $ENV{'TMPDIR'} || "/tmp";
    if ($ENV{'LSB_JOBID'}) {
        my $lsf_possible_tempdir = sprintf("%s/%s.tmpdir", $ENV{'TMPDIR'}, $ENV{'LSB_JOBID'});
        $tmp_location = $lsf_possible_tempdir if (-d $lsf_possible_tempdir);
    }
    # tempdir() thows its own exception if there's a problem
    my $dir = File::Temp::tempdir($template, DIR=>$tmp_location, CLEANUP => 1);
    $self->create_directory($dir);

    if (ref($self)) {
        return $self->{base_temp_directory} = $dir;
    }
    else {
        # work as a class method
        return $base_temp_directory = $dir;
    }

    unless ($dir) {
        Carp::croak("Unable to determine base_temp_directory");
    }

    return $dir;
}

our $anonymous_temp_file_count = 0;
sub create_temp_file_path {
    my $self = shift;
    my $name = shift;
    unless ($name) {
        $name = 'anonymous' . $anonymous_temp_file_count++;
    }
    my $dir = $self->base_temp_directory;
    my $path = $dir .'/'. $name;
    if (-e $path) {
        Carp::croak "temp path '$path' already exists!";
    }

    if (!$path or $path eq '/') {
        Carp::croak("create_temp_file_path() failed");
    }

    return $path;
}

sub create_temp_file {
    my $self = shift;
    my $path = $self->create_temp_file_path(@_);
    my $fh = IO::File->new($path, '>');
    unless ($fh) {
        Carp::croak "Failed to create temp file $path: $!";
    }
    return ($fh,$path) if wantarray;
    return $fh;
}

sub create_temp_directory {
    my $self = shift;
    my $path = $self->create_temp_file_path(@_);
    $self->create_directory($path);
    return $path;
}

sub create_directory {
    my ($self, $directory) = @_;

    unless ( defined $directory ) {
        Carp::croak("Can't create_directory: No path given");
    }

    # FIXME do we want to throw an exception here?  What if the user expected
    # the directory to be created, not that it already existed
    return $directory if -d $directory;

    my $errors;
    # make_path may throw its own exceptions...
    File::Path::make_path($directory, { mode => 02775, error => \$errors });
    
    if ($errors and @$errors) {
        my $message = "create_directory for path $directory failed:\n";
        foreach my $err ( @$errors ) {
            my($path, $err_str) = %$err;
            $message .= "Pathname " . $path ."\n".'General error' . ": $err_str\n";
        }
        Carp::croak($message);
    }
    
    unless (-d $directory) {
        Carp::croak("No error from 'File::Path::make_path', but failed to create directory ($directory)");
    }

    return $directory;
}

sub create_symlink {
    my ($self, $target, $link) = @_;

    unless ( defined $target ) {
        Carp::croak("Can't create_symlink: no target given");
    }

    unless ( defined $link ) {
        Carp::croak("Can't create_symlink: no 'link' given");
    }

    unless ( -e $target ) {
        Carp::croak("Cannot create link ($link) to target ($target): target does not exist");
    }
    
    if ( -e $link ) { # the link exists and points to spmething
        Carp::croak("Link ($link) for target ($target) already exists.");
    }
    
    if ( -l $link ) { # the link exists, but does not point to something
        Carp::croak("Link ($link) for target ($target) is already a link.");
    }

    unless ( symlink($target, $link) ) {
        Carp::croak("Can't create link ($link) to $target\: $!");
    }
    
    return 1;
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
