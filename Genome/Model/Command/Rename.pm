package Genome::Model::Command::Rename;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Rename {
    is => 'Genome::Model::Command',
    has => [
    new_name => {
        is => 'Text',
        doc => 'The new name',
    },
    ],
};

########################################

sub sub_command_sort_position { 5 }

sub help_brief {
    return 'Rename a model';
}

sub help_detail {
    return 'Rename a model';
}

sub help_synopsis {
    return <<"EOS"
    genome model rename --model-id \$ID --new-name \$NEW_NAME
EOS
}

########################################

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->new_name ) { # simple check here
        $self->error_message("A new name is required");
        return;
    }

    return $self;
}

sub execute {
    my $self = shift;

    $self->_verify_name # full check here
        or return;
   
    my $old_name = $self->model->name;
    $self->model->name( $self->new_name )
        or return;

    # Sanity check
    unless ( $self->new_name eq $self->model->name ) {
        $self->error_message(
            sprintf(
                'Could not rename model (<Id> %s <Name> %s) to new name (%s) for unkown reasons', 
                $self->model_id, 
                $self->model_name, 
                $self->new_name,
            )
        );
        return;
    }

    printf(
        "Renamed model (<Id> %s) from %s to %s\n",
        $self->model_id, 
        $old_name,
        $self->model_name,
    );

    return 1;
}

sub _verify_name {
    my $self = shift;

    unless ( $self->new_name ) { # will catch undef, 0, and ''
        $self->error_message("A new name is required to rename a model");
        return;
    }

    if ( $self->new_name eq $self->model_name ) {
        $self->error_message("New name is the same as the model's current name");
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

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

