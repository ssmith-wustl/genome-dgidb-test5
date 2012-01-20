package Genome::Model::Command::Admin::FailedModelTickets;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Error qw(:try);
use File::Find 'find';
use File::Grep 'fgrep';
require IO::Prompt;
require RT::Client::REST;
require RT::Client::REST::Ticket;

class Genome::Model::Command::Admin::FailedModelTickets {
    is => 'Command::V2',
    doc => 'find failed cron models, check that they are in a ticket',
};

sub help_detail {
    return <<HELP;
This command collects cron models by failed build events and scours tickets for them. If they are not found, the models are summaraized first by the error entry log and then by grepping the error log files. The summary is the printed to STDOUT.
HELP
}

sub execute {
    my $self = shift;

    # Connect
    my $pw = IO::Prompt::prompt('Ticket Tracker Password: ', -e => "*");
    chomp $pw;
    return if not $pw;
    my $username = Genome::Sys->username;

    local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    my $cookie_file = $ENV{HOME}."/.rt_cookie";
    my $cookie_jar = HTTP::Cookies->new(file => $cookie_file);
    my $rt = RT::Client::REST->new(server => 'https://rt.gsc.wustl.edu/', _cookie => $cookie_jar);
    try {
        $rt->login(username => $username, password => $pw->{value});
    } catch Exception::Class::Base with {
        my $msg = shift;
        die $msg->message;
    };
    $rt->_cookie->{ignore_discard} = 1;
    $rt->_cookie->save($cookie_file);

    # Find cron models by failed build events
    $self->status_message('Looking for failed models...');
    my @events = Genome::Model::Event->get(
        event_status => 'Failed',
        event_type => 'genome model build',
        user_name => 'apipe-builder',
        -hint => [qw/ build /],
    );
    if ( not @events ) {
        $self->status_message('No failed build events found!');
        return 1;
    }
    my %models_and_builds;
    for my $event ( @events ) {
        next if not $event->build_id;
        my $build = Genome::Model::Build->get(id => $event->build_id, -hint => [qw/ model events /]);
        my $model = $build->model;
        #If the latest build of the model succeeds, ignore those old
        #failing ones that will be cleaned by admin "cleanup-succeeded".
        next if $model->status eq 'Succeeded';
        next if $models_and_builds{ $model->id } and $models_and_builds{ $model->id }->id > $build->id;
        $models_and_builds{ $model->id } = $build;
    }
    $self->status_message('Found '.keys(%models_and_builds).' models');

    # Retrieve tickets
    $self->status_message('Looking for tickets...');
    my @ticket_ids = $rt->search(
        type => 'ticket',
        query => "Queue = 'apipe-builds' AND ( Status = 'new' OR Status = 'open' )",
    );
    $self->status_message('Found '.@ticket_ids.' tickets');
    my %tickets;
    $self->status_message('Matching failed models and tickets...');
    for my $ticket_id ( @ticket_ids ) {
        my $ticket = RT::Client::REST::Ticket->new(
            rt => $rt,
            id => $ticket_id,
        )->retrieve;
        my $transactions = $ticket->transactions;
        my $transaction_iterator = $transactions->get_iterator;
        while ( my $transaction = &$transaction_iterator ) {
            my $content = $transaction->content;
            for my $model_id ( keys %models_and_builds ) {
                my $build_id = $models_and_builds{$model_id}->id;
                next if $content !~ /$model_id/ or $content !~ /$build_id/;
                delete $models_and_builds{$model_id};
                push @{$tickets{$ticket_id.' '.$ticket->subject}}, $model_id;
            }
        }
    }

    # Consolidate errors
    $self->status_message('Consolidating errors...');
    my %build_errors;
    my %guessed_errors;
    my $models_with_errors = 0;
    my $models_with_guessed_errors = 0;
    for my $build ( values %models_and_builds ) {
        my $key = 'Unknown';
        my $msg = 'Failure undetermined!';
        my $error = $self->_pick_optimal_error_log(@error_logs);
        if ( $error
                and
            ( ($error->file and $error->line) or ($error->inferred_file and $error->inferred_line) )
                and
            ($error->message or $error->inferred_message)
        ) {
            if ( $error->file and $error->line ) {
                $key = $error->file.' '.$error->line;
            } elsif ( $error->inferred_file and $error->inferred_line ) {
                $key = $error->inferred_file.' '.$error->inferred_line;
            } else {
                $key = 'unkown';
            }

            if ( $error->message ) {
                $msg = $error->message;
            } elsif ( $error->inferred_message ) {
                $msg = $error->inferred_message;
            } else {
                $msg = 'unkown';
            }

            $models_with_errors++;
        }
        elsif ( my $guessed_error = $self->_guess_build_error($build) ) {
            if ( not $guessed_errors{$guessed_error} ) {
                $guessed_errors{$guessed_error} = scalar(keys %guessed_errors) + 1;
            }
            $key = "Unknown, best guess #".$guessed_errors{$guessed_error};
            $msg = $guessed_error;
            $models_with_guessed_errors++;
        }
        $build_errors{$key} = "File:\n$key\nExample error:\n$msg\nModel\t\tBuild\t\tType/Failed Stage:\n" if not $build_errors{$key};
        my $type_name = $build->type_name;
        $type_name =~ s/\s+/\-/g;
        my %failed_events = map { $_->event_type => 1 } grep { $_->event_type ne 'genome model build' } $build->events('event_status in' => [qw/ Crashed Failed /]);
        my $failed_event = (keys(%failed_events))[0] || '';
        $failed_event =~ s/genome model build $type_name //;
        $build_errors{$key} .= join("\t", $build->model_id, $build->id, $type_name.' '.$failed_event)."\n";
    }

    # Report
    my $models_in_tickets = map { @{$tickets{$_}} }keys %tickets;
    my $models_not_in_tickets = keys %models_and_builds;
    $self->status_message('Models: '.($models_in_tickets+ $models_not_in_tickets));
    $self->status_message('Models in tickets: '.$models_in_tickets);
    $self->status_message('Models not in tickets: '.$models_not_in_tickets);
    $self->status_message('Models with error log: '.$models_with_errors);
    $self->status_message('Models with guessed errors: '.$models_with_guessed_errors);
    $self->status_message('Models with unknown failures: '.($models_not_in_tickets - $models_with_errors - $models_with_guessed_errors));
    $self->status_message('Summerized errors: ');
    $self->status_message(join("\n", map { $build_errors{$_} } sort keys %build_errors));

    return 1;
}

sub _guess_build_error {
    my ($self, $build) = @_;

    my $data_directory = $build->data_directory;
    my $log_directory = $data_directory.'/logs';
    my %errors;
    find(
        sub{
            return unless $_ =~ /\.err$/;
            my @grep = (fgrep { /ERROR:\s+/ } $_ );
            return if $grep[0]->{count} == 0;
            for my $line ( values %{$grep[0]->{matches}} ) {
                my ($err) = (split(/ERROR:\s+/, $line))[1];
                chomp $err;
                next if $err eq "Can't convert workflow errors to build errors";
                next if $err eq 'relation "error_log_entry" does not exist';
                next if $err =~ /current transaction is aborted/;
                next if $err =~ /run_workflow_ls/;
                $errors{$err} = 1;
            }
        },
        $log_directory,
    );

    return join("\n", sort keys %errors);
}

sub _pick_optimal_error_log{
    my $self = shift;
    my @errors = grep Genome::Model::Build::ErrorLogEntry->get(build_id => $build->id);
    my @optimal_errors = grep($_->file, @errors);
    unless (@optimal_errors){
        @optimal_errors = grep($_->inferred_file, @errors);
    }
    unless(@optimal_errors){
        return 0;
    }
    return shift @optimal_errors;
}

1;

