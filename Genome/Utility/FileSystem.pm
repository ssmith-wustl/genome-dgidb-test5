package Genome::Utility::FileSystem;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require File::Path;

class Genome::Utility::FileSystem {
    is => 'UR::Object',
};

sub create_directory {
    my ($self, $directory) = @_;

    unless ( defined $directory ) {
        $self->error_message("Need directory to create");
        return;
    }

    return $directory if -d $directory;

    if ( -f $directory ) {
        $self->error_message("Can't create directory ($directory), already exists as a file");
        return;
    }

    if ( -l $directory ) {
        $self->error_message("Can't create directory ($directory), already exists as a symlink");
        return;
    }

    eval{ File::Path::mkpath($directory, 0, 02775); };

    if ( $@ ) {
        $self->error_message("Can't create directory ($directory) w/ File::Path::mkpath: $@");
        return;
    }
    
    unless (-d $directory) {
        $self->error_message("No error from 'File::Path::mkpath', but failed to create directory ($directory)");
        return;
    }

    return $directory;
}

sub create_symlink {
    my ($self, $target, $link) = @_;

    #TODO verify that it points to the given spot??
    return 1 if -l $link; 

    if ( -f $link ) {
        $self->error_message("Can't create link ($link), already exists as a file");
        return;
    }

    if ( -d $link ) {
        $self->error_message("Can't create link ($link), already exists as a directory");
        return;
    }


    unless ( symlink($target, $link) ) {
        $self->error_message("Can't create link ($link) to $target\: $!");
        return;
    }
    
    return 1;
}

1;

=pod

=head1 Name

Genome::Utility::FileSystem;

=head1 Synopsis

Houses some generic file and directory methods

=head1 Usage

 require Genome::Utility::FileSystem;

 # Call methods directly:
 Genome::Utility::FileSystem->create_directory($new_directory);

=head1 Methods

=head2 create_directory

 Genome::Utility::FileSystem->create_directory('/tmp/users')
    or die;
 
=over

=item I<Synopsis>   Creates the directory with the default permissions 02775

=item I<Arguments>  directory (string)

=item I<Returns>    true on success, false on failure

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
