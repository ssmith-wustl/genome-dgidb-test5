package Genome::Model::Command::Services::BuildCzarRt;

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

class Genome::Model::Command::Services::BuildCzarRt { 
    is => 'Command::V2',
};

sub execute {
    my $self = shift;

    # Connect to RT
    my $pw = IO::Prompt::prompt('RT Password: ', -e => "*");
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

    # Find models
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
        next if $models_and_builds{ $model->id } and $models_and_builds{ $model->id }->id > $build->id;
        $models_and_builds{ $model->id } = $build;
    }
    $self->status_message('Found '.keys(%models_and_builds).' models');

    # Retrieve tickets
    $self->status_message('Looking for build czar tickets...');
    my @ticket_ids = $rt->search(
        type => 'ticket',
        query => "Queue = 'apipe-support' AND ( Status = 'new' OR Status = 'open' ) AND Subject LIKE 'build czar'",
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
    for my $build ( values %models_and_builds ) {
        my @error_logs = Genome::Model::Build::ErrorLogEntry->get(build_id => $build->id);
        my $key = 'Unknown';
        my $msg = 'Failure undetermined!';
        if ( @error_logs and $error_logs[0]->inferred_file ) {
            $key = $error_logs[0]->inferred_file.' '.$error_logs[0]->inferred_line;
            $msg = $error_logs[0]->inferred_message;
            $models_with_errors++;
        }
        elsif ( my $guessed_error = $self->_guess_build_error($build) ) {
            if ( not $guessed_errors{$guessed_error} ) {
                $guessed_errors{$guessed_error} = scalar(keys %guessed_errors) + 1;
            }
            $key = "Unknown, best guess #".$guessed_errors{$guessed_error};
            $msg = $guessed_error;
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
    $self->status_message('Models in RT: '.$models_in_tickets);
    $self->status_message('Models not in RT: '.$models_not_in_tickets);
    $self->status_message('Models with error log: '.$models_with_errors);
    $self->status_message('Models with unknown failures: '.($models_not_in_tickets - $models_with_errors));
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
                $errors{$err} = 1;
            }
        },
        $log_directory,
    );

    return join("\n", sort keys %errors);
}

1;

