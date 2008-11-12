package Genome::Utility::FileSystem;

use strict;
use warnings;

use Genome;

use Data::Dumper;

class Genome::Utility::FileSystem {
    is => 'UR::Object',
};

sub create_directory {
    my ($self, $directory) = @_;

    $self->error_message("Need directory to create") unless defined $directory;
    
    return $directory if -d $directory;

    if ( -f $directory ) {
        $self->error_message("Can't create directory ($directory), already is a file");
        return;
    }

    if ( system "mkdir -p $directory" ) {
        $self->error_message("Can't create directory ($directory) w/ mkdir: $!");
        return;
    }
    
    unless (-d $directory) {
        $self->error_message("No error from 'mkdir', but failed to create directory ($directory)");
        return;
    }

    return $directory;
}

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

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

