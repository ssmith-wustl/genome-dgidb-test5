package Genome::Model::Report::BuildFailed;

use strict;
use warnings;

use Genome;
use Workflow;

use Data::Dumper 'Dumper';
require Text::Wrap;

class Genome::Model::Report::BuildFailed {
    is => 'Genome::Model::Report::BuildEventBase',
    has => [
    errors => {
        is => 'Array',
        doc => 'The erros from a builds workflow.',
    },
    ],
};

sub create {
    my ($class, %params) = @_;

    my $errors = delete $params{errors};
    my $self = $class->SUPER::create(%params)
        or return;

    unless ( $errors and @$errors ) {
        $self->error_message('No errors given to generate build fail report');
        $self->delete;
        return;
    }

    $self->errors($errors);

    return $self;
}

sub _generate_data {
    my $self = shift;

    $self->_add_build_event_dataset
        or return; # bad
    
    #< Errors >#
    my $errors = $self->errors;
    my @rows;
    my @headers = (qw/
        build-event-id stage-event-id stage step-event-id step error error-wrapped error-log
        /);
    for my $error ( @$errors ) {
        $self->_validate_error($error)
            or return; #bad
        my %info = $self->_parse_error($error)
            or next; # ok
        #print Dumper(\@headers, \%info, $error->path_name);
        push @rows, [ map { $info{$_} } @headers ];
    }

    unless ( @rows ) { # bad
        $self->error_message('Could not find proper errors to report for failed build.  Errors given:');
        $self->error_message( Dumper($errors) );
        return;
    }

    $self->_add_dataset(
        name => 'errors',
        row_name => 'error',
        headers => \@headers,
        rows => \@rows,
    ) or return; # bad

    return 1;
}

sub _validate_error {
    my ($self, $error) = @_;

    unless ( $error->path_name ) { 
        $self->error_message("No path name found in error: ".$error->id);
        $self->error_message( Dumper($error) );
        return;
    }

    #$self->status_message('Error path name: '.$error->path_name);

    return 1;
}

sub _parse_error {
    my ($self, $error) = @_;

    my %info;
    my @tokens = split(/\//, $error->path_name);
    unless ( @tokens ) { # bad
        $self->error_message("Error parsing error path name: ".$error->path_name);
        print Dumper($error);
        return;
    }
    
    return unless @tokens == 3; # ok, only looking for errors with 3 parts

    # PATH NAME:
    # '%s all stages/%s %s/%s %s'
    # $build_event_id
    # $stage_event_id, (currently the build_event_id, but if stages get ids...)
    # $stage
    # $step
    # $step_event_id
    @info{qw/ build-event-id /} = split(/\s/, $tokens[0], 2);
    @info{qw/ stage-event-id stage /} = split(/\s/, $tokens[1]);
    @info{qw/ step step-event-id /} = split(/\s/, $tokens[2]);

    $info{error} = $error->error;
    # wrapping cuz handling this in xslt is a REAL pain
    local $Text::Wrap::columns = 70;
    $info{'error-wrapped'} = Text::Wrap::wrap('', '', $error->error);
    $info{'error-log'} = sprintf(
        '%s/logs/%s.err', $self->build->data_directory, $info{'step-event-id'}
    );

    return %info;
}

1;

#$HeadURL$
#$Id$
