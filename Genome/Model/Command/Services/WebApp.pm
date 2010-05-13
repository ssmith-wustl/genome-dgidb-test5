package Genome::Model::Command::Services::WebApp;

use strict;
use warnings;

use Genome;
use Workflow;
use Sys::Hostname;
use AnyEvent;
use AnyEvent::Util;
use Plack::Runner;

class Genome::Model::Command::Services::WebApp {
    is  => 'Command',
    has => [
        browser => {
            ## this property has its accessor overriden to provide defaults
            is  => 'String',
            doc => 'command to run to launch the browser'
        },
        port => {
            is    => 'Number',
            value => '8090',
            doc   => 'tcp port for internal server to listen'
        },
        url => {
            is             => 'Text',
            calculate_from => 'port',
            calculate      => q(
                my $hostname = Sys::Hostname::hostname;
                return "http://$hostname:$port/";
            )
        }
    ],
};

sub execute {
    my $self = shift;

    print $self->browser . "\n";
    print $self->url . "\n";

    $self->fork_and_call_browser
      if ( $ENV{DISPLAY} && !( $ENV{SSH_CLIENT} || $ENV{SSH_CONNECTION} ) );

    $self->run_starman;
}

sub fork_and_call_browser {
    my ($self) = @_;

    my $command = [ $self->browser, $self->url ];

    run_cmd $command,
      '>'        => \*STDOUT,
      '2>'       => \*STDERR,
      close_all  => 1,
      on_prepare => sub {
        sleep 2;
      }
}

sub psgi_path {
    my $module_path = __PACKAGE__->get_class_object->module_path;
    $module_path =~ s/\.pm$//g;

    return $module_path;
}

sub res_path {
    $_[0]->psgi_path . '/resource';
}

sub run_starman {
    my ($self) = @_;

    my $runner = Plack::Runner->new(
        server => 'Starman',
        env    => 'single_user'
    );

    my $psgi_path = $self->psgi_path . '/Main.psgi';
    $runner->parse_options( '--app', $psgi_path, '--port', $self->port,
        '--workers', 4, '-R', Genome->base_dir . ',' . Workflow->base_dir );

    $runner->run;
}

sub browser {
    my $self = shift;

    return $self->__browser(@_) if (@_);

    my $b = $self->__browser;
    return $b if ( defined $b );

    if ( exists $ENV{BROWSER} && defined $ENV{BROWSER} ) {
        return $self->__browser( $ENV{BROWSER} );
    }

    return $self->__browser('firefox');
}

sub help_brief {
    return 'launch single user web app';
}

sub is_sub_command_delegator {
    return;
}

1;

#$HeadURL$
#$Id$
