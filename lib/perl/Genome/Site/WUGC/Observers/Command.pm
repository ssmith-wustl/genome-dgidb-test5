package Genome::Site::WUGC::Observers::Command;

use strict;
use warnings;
use Command::V1;


Command::V1->add_observer(
    aspect => 'error_die',
    callback => \&command_death_handler,
);

Command::V1->add_observer(
    aspect => 'error_rv_false',
    callback => \&command_death_handler,
);

sub command_death_handler {
    return 1 unless $ENV{GENOME_LOG_COMMAND_ERROR};

    my $self = shift;
    my $aspect = shift;
    my %command_death_metrics = @_;

    my $message = $command_death_metrics{error_message} || 0;
    my $package = $command_death_metrics{error_package} || 0;
    my $file = $command_death_metrics{error_file} || 0;
    my $subroutine = $command_death_metrics{error_subroutine} || 0;
    my $line = $command_death_metrics{error_line} || 0;

    #The die message is parsed with a regex to glean extra information
    my $inferred_message = $command_death_metrics{inferred_message} || 0;
    my $inferred_file = $command_death_metrics{inferred_file} || 0;
    my $inferred_line = $command_death_metrics{inferred_line} || 0;

    my $build_id = $command_death_metrics{build_id} || 0;

    my $includes = join(' ', map { '-I ' . $_ } UR::Util::used_libs);

    my $cmd = <<EOF
$^X $includes -e 'use Genome;
Genome::Model::Build::ErrorLogEntry->create(
message=>q{$message},
package=>q{$package},
file=>q{$file},
subroutine=>q{$subroutine},
line=>q{$line},
inferred_message=>q{$inferred_message},
inferred_file=>q{$inferred_file},
inferred_line=>q{$inferred_line},
build_id=>q{$build_id},
);
UR::Context->commit;'
EOF
;

    Genome::Sys->shellcmd(cmd => $cmd);

    return 1;
}

1;
