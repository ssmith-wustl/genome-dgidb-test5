package Genome::Model::Tools::Dacc::Upload;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Dacc::Upload { 
    is => 'Genome::Model::Tools::Dacc',
    has => [
        files => {
            is => 'Text',
            is_many => 1,
            shell_args_position => 3,
            doc => '',
        },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    return $self;
}

sub execute {
    my $self = shift;

    if  ( not $self->is_host_a_blade ) {
        $self->error_message('To upload from the DACC, this command must be run on a blade');
        return;
    }

    for my $file ( $self->files ) {
        if ( not -e $file ) {
            $self->error_message("File to upload ($file) does not exist");
            return;
        }
    }
    my $file_string = join(' ', $self->files);
    $self->status_message("Files: $file_string");

    my $cmd = $self->base_command.' -d '.$file_string.' '.$self->dacc_remote_directory;
    my $rv = eval{ Genome::Utility::FileSystem->shellcmd(cmd => $cmd); };
    if ( not $rv ) {
        $self->error_message("Aspera command failed: $cmd");
        return;
    }

    return 1;
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

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

