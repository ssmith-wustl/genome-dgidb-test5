package Genome::ProcessingProfile::Command::Rename;

#REVIEW fdu 11/20/2009
#1. Need check if new pp name already exists in pp table 
#2. Need print out the warning list of all the models using current pp name
#3. Remove the part of pod

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Command::Rename {
    is => 'Genome::ProcessingProfile::Command',
    has => [
        new_name => {
            is => 'Text',
            shell_args_position => 2,
            doc => 'The new name for the processing profile.',
        },
    ],
};

sub execute {
    my $self = shift;

    # Verify processing profile 
    $self->_verify_processing_profile
        or return;

    # Verify new name
    unless ( $self->new_name =~ /\w+/ ) {
        $self->error_message("Letters are required to be included in the new name");
        return;
    }
    
    if ( $self->new_name eq $self->processing_profile->name ) {
        $self->error_message(
            sprintf('Processing profile (<ID> %s) already is named "%s"', $self->processing_profile->id, $self->new_name)
        );
        return;
    }
    
    # Rename
    $self->processing_profile->name( $self->new_name );

    # Sanity chack
    unless ( $self->new_name eq $self->processing_profile->name ) {
        $self->error_message(
            sprintf(
                'Could not rename processing profile (<ID> %s) to "%s" for unkown reasons', 
                $self->processing_profile->id, 
                $self->new_name,
            )
        );
        return;
    }

    printf(
        'Renamed processing profile (<ID> %s) to "%s"', 
        $self->processing_profile->id, 
        $self->processing_profile->name, 
    );
    print "\n";
    
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

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

