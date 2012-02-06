package Genome::Model::Build::Error;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Text::Wrap;

class Genome::Model::Build::Error {
    is => 'UR::Object',
    has_optional => [
        # these are only set for old, event-based workflows:
        build_event => {
            is => 'Genome::Model::Event',
            id_by => 'build_event_id',
            doc => 'The main build event.',
        },
        build_event_id => {
            is => 'Integer',
            doc => 'The main build event id.',
        },
        stage_event_id => {
            is => 'Integer',
            doc => 'The event id of the stage.',
        },
        step_event => {
            is => 'Genome::Model::Event',
            id_by => 'step_event_id',
            doc => 'The step event.',
        },
        step_event_id => {
            is => 'Integer',
            doc => 'The event id of the step.',
        },
    ],
    has_constant => [
        # used for both old and new style events 
        stage => {
            is => 'Text',
            doc => 'The name of the stage.',
        },
        step => {
            is => 'Text',
            doc => 'The name of the step.',
        },
        error => {
            is => 'Text',
            doc => 'Error message text.',
        },
        error_wrapped => {
            is => 'Text',
            calculate_from => [qw/ error /],
            calculate => q{
                local $Text::Wrap::columns = $_[1] || 70;
                return Text::Wrap::wrap('', '', $error);
            },
        },
    ],
};

sub error_log {
    my $self = shift;

    my $step_event = $self->step_event;
    unless ( $step_event ) {
        $DB::single = 1;
        $self->error_message(
            sprintf(
                "Can't get step event for id (%s) to get error log file.",
                $self->step_event_id,
            )
        );
        Carp::cluck("don't go here!");
        return;
    }
    
    return $self->step_event->error_log_file;
}

sub error_log_for_web {
    my $self = shift;

    my $step_event = $self->step_event;
    unless ( $step_event ) {
        $self->error_message(
            sprintf(
                "Can't get step event for id (%s) to get error log file.",
                $self->step_event_id,
            )
        );
        return;
    }
    
    return 'file://'.$self->step_event->error_log_file;
}

sub create_from_workflow_errors {
    my ($class, @wf_errors) = @_;

    $DB::single = 1;

    # wf errors
    unless ( @wf_errors ) {
        $class->error_message("No workflow errors given to create build errors.");
        return;
    }

    my @errors;
    for my $wf_error ( @wf_errors ) {
        $class->_validate_error($wf_error)
            or return; #bad
        my %error_params = $class->_parse_error($wf_error)
            or next; # ok
        #print Dumper(\%params, $wf_error->path_name);
        
        my $error = eval { $class->create(%error_params) };
        unless ( $error ) {
            $class->error_message("Can't create build error from workflow error. See above.");
            return;
        }
        push @errors, $error;
    }

    return @errors;
}

sub _validate_error {
    my ($class, $error) = @_;

    unless ($error->error) {
        $class->error_message("No message found in error: ".$error->id);
        $class->error_message( Dumper($error) );
        return;
    }

    return 1;
}

sub _parse_error {
    my ($class, $error) = @_;

    my %error;
    my @tokens = split(m#/#, $error->path_name);
    if (@tokens == 3) {
        # old, event-based build error

        unless ( @tokens ) { # bad
            $class->error_message("Error parsing error path name: ".$error->path_name);
            print Dumper($error);
            return;
        }
        
        # PATH NAME:
        # '%s all stages/%s %s/%s %s'
        # $build_event_id
        # $stage_event_id, (currently the build_event_id, but if stages get ids...)
        # $stage
        # $step
        # $step_event_id
        @error{qw/ build_event_id /} = split(/\s/, $tokens[0], 2);
        @error{qw/ stage_event_id stage /} = split(/\s/, $tokens[1]);
        @error{qw/ step step_event_id /} = split(/\s/, $tokens[2]);
        $error{error} = $error->error;
    }
    else {
        $error{error} = $error->error;
        $error{stage} = 'na';
        $error{step} = 'na';
    }

    return %error;
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

#$HeadURL$
#$Id$

