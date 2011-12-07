package Genome::Sys::Service::Example1;
use strict;
use warnings;
use Genome;

class Genome::Sys::Service::Example1 {
    is => ['Genome::Sys::Service','UR::Singleton'],
    doc => "example service 1"
};

sub host {
    "example1 host";
}

sub restart_command {
    "example1 restart command";
}

sub stop_command {
    "example1 stop command";
}

sub log_path {
    "example1 log path";
}

sub status {
    "example1 status";
}

sub pid_status {
    "example1 pid status";
}

sub pid_name {
    "example1 pid name";
}

sub url {
    "example1 url";
}

1;

