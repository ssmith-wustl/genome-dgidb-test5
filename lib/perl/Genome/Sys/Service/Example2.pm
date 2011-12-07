package Genome::Sys::Service::Example2;
use strict;
use warnings;
use Genome;

class Genome::Sys::Service::Example2 {
    is => ['Genome::Sys::Service','UR::Singleton'],
    doc => "example service 2"
};

sub host {
    "example2 host";
}

sub restart_command {
    "example2 restart command";
}

sub stop_command {
    "example2 stop command";
}

sub log_path {
    "example2 log path";
}

sub status {
    "example2 status";
}

sub pid_status {
    "example2 pid status";
}

sub pid_name {
    "example2 pid name";
}

sub url {
    "example2 url";
}

1;

