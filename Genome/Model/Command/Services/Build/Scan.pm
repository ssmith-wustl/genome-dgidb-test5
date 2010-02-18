package Genome::Model::Command::Services::Build::Scan;

use strict;
use warnings;

use Guard;
use Workflow;

class Genome::Model::Command::Services::Build::Scan {
    is  => 'Command',
    doc => 'scan all non abandoned, completed or crashed builds for problems'
};

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my (
        $builds_without_job, $builds_with_job, $job_without_build,
        $events_with_job,    $build_inner_events
    ) = $self->build_lists;

    my $state;
    my $build_id;
    my @lsf_id;
    my $event_status;
    my $action;
    my $owner;

    print <<'    MARK';
State      Build ID        LSF JOB ID Current Status  Action     Owner
    MARK

    no warnings;
    format STDOUT =
@<<<<<<<<< @<<<<<<<<<<<<<< @<<<<<<<<< @<<<<<<<<<<<<<< @<<<<<<<<< @<<<<<<<<<
$state,    $build_id,      shift @lsf_id,   $event_status, $action, $owner
                           @<<<<<<<<< ~~
                           shift @lsf_id 
.
    use warnings;

    while ( my ( $bid, $lsf_job_ids ) = each %$builds_without_job ) {
        $state    = 'no job';
        $build_id = $bid;
        my $event = shift @$lsf_job_ids;
        $event_status = $event->event_status;
        $owner        = $event->user_name;
        my @event_ids_only = keys %$events_with_job;
        my $fixed_status =
          $self->derive_build_status( $build_inner_events->{$build_id},
            \@event_ids_only );
        $action = $self->action_for_derived_status($fixed_status);

        @lsf_id = @$lsf_job_ids;
        write STDOUT;
    }

    while ( my ( $bid, $lsf_job_ids ) = each %$builds_with_job ) {
        $state    = 'okay';
        $build_id = $bid;
        my $event = shift @$lsf_job_ids;
        $event_status = $event->event_status;
        $owner        = $event->user_name;
        $action       = 'none';
        my %joined = map { $_ => 1 } @{ $lsf_job_ids->[0] },
          @{ $lsf_job_ids->[1] };
        @lsf_id = keys %joined;
        write STDOUT;
    }

    while ( my ( $bid, $lsf_job_ids ) = each %$job_without_build ) {
        $state    = 'no build';
        $build_id = $bid;
        my $event = shift @$lsf_job_ids;
        $event_status = $event->event_status;
        $owner        = $event->user_name;
        my @event_ids_only = keys %$events_with_job;
        my $fixed_status =
          $self->derive_build_status( $build_inner_events->{$build_id},
            \@event_ids_only );
        $action = 'kill';
        my $daction = $self->action_for_derived_status($fixed_status);

        if ( $daction ne $self->action_for_derived_status($event_status) ) {
            $action .= ' ' . $daction;
        }
        @lsf_id = @$lsf_job_ids;
        write STDOUT;
    }

}

sub action_for_derived_status {
    my $self = shift;
    my $derived = shift || return 'none';

    if (   $derived eq 'Failed'
        || $derived eq 'Crashed'
        || $derived eq 'Running'
        || $derived eq 'Scheduled'
        || $derived eq 'unknown' )
    {
        return 'fail';
    } elsif ( $derived eq 'Succeeded' ) {
        return 'success';
    } elsif ( $derived eq 'Abandoned' ) {
        return 'abandon';
    } else {
        return 'none';
    }
}

sub build_lists {
    my $self = shift;

    my $builds_db = {};
    {
        my $iter = Genome::Model::Event->create_iterator(
            event_type   => 'genome model build',
            event_status => [ 'Scheduled', 'Running' ]
        );
        while ( my $event = $iter->next ) {
            $builds_db->{ $event->build_id } = [ $event->lsf_job_id, $event ];
        }
    }

    my $events_lsf = {};
    my $builds_lsf = {};
    {
        open my $bjobs, "bjobs -u all -w |";
        while ( my $line = <$bjobs> ) {
            if ( $line =~ /^(\d+).+?build run.+?--build-id (\d+)/ ) {
                $builds_lsf->{$2} ||= [];
                push @{ $builds_lsf->{$2} }, $1;
            }
            if ( $line =~
/^(\d+).+?(\d+) (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/
              )
            {

                # this is a terrible match, but its the best i can do right now
                $events_lsf->{$2} ||= [];
                push @{ $events_lsf->{$2} }, $1;
            }
        }
        close $bjobs;
    }

    my $builds_both = { map { $_ => 1 } keys %$builds_lsf, keys %$builds_db };

    my $inner_events_db = {};
    {
        my $iter = Genome::Model::Event->create_iterator(
            build_id   => [ keys %$builds_both ],
            event_type => { operator => '!=', value => 'genome model build' }
        );
        while ( my $event = $iter->next ) {
            $inner_events_db->{ $event->build_id } ||= {};
            $inner_events_db->{ $event->build_id }->{ $event->id } = $event;
        }
    }

    foreach my $bid ( keys %$builds_both ) {
        my $event =
          exists $builds_db->{$bid}
          ? $builds_db->{$bid}->[1]
          : Genome::Model::Event->get(
            event_type => 'genome model build',
            build_id   => $bid
          );
        if ( exists $builds_lsf->{$bid} && exists $builds_db->{$bid} ) {
            my $from_lsf = delete $builds_lsf->{$bid};
            my $from_db  = delete $builds_db->{$bid};
            pop @$from_db;

            $builds_both->{$bid} = [ $event, $from_lsf, $from_db ];
        } else {

            if ( exists $builds_lsf->{$bid} ) {
                unshift @{ $builds_lsf->{$bid} }, $event;
            } elsif ( exists $builds_db->{$bid} ) {
                unshift @{ $builds_db->{$bid} }, $event;
                pop @{ $builds_db->{$bid} };
            }
            delete $builds_both->{$bid};
        }
    }

    return $builds_db, $builds_both, $builds_lsf, $events_lsf, $inner_events_db;
}

sub derive_build_status {
    my $self              = shift;
    my $events_in_build   = shift;
    my $running_event_ids = shift;

    my %status_prio = (
        Failed    => 90,
        Crashed   => 80,
        Running   => 70,
        Scheduled => 30,
        Succeeded => 20,
        Abandoned => 10,
        unknown   => -100,
    );

    # Using the above status priority list we will derive a new
    # build_event status.  At first glance it seems like Abandoned
    # is too low, but we only want the whole build to show that
    # status if there is nothing else higher.  In the past it was
    # common to Abandon a single lane and restart the build

    my $new_status = 'unknown';
    while ( my ( $eid, $event ) = each %$events_in_build ) {
        my $event_status = $event->event_status;
        if ( $event_status eq 'Running' && defined $running_event_ids ) {
            ## see if its really running
            my $found = 0;
            foreach (@$running_event_ids) {
                if ( $_ == $event->id ) {
                    $found = 1;
                    last;
                }
            }

            $event_status = 'Crashed' if !$found;
        }

        if ( exists $status_prio{$event_status}
            && $status_prio{$event_status} > $status_prio{$new_status} )
        {
            $new_status = $event_status;
        }
    }
    return $new_status;
}

1;
