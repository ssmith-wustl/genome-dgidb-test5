package Genome::Role::Logger;

use Genome;
use Log::Dispatch;
use Log::Dispatch::Screen;
use Log::Dispatch::FileRotate;

our @log_levels = qw(debug info notice warning error critical alert emergency);

class Genome::Role::Logger {
    has => [
        screen => {
            is => 'Boolean',
            default => 1,
            doc => 'Display output to screen.',
        },
        screen_level => {
            is => 'Text',
            default => 'warning',
            valid_values => \@log_levels,
            doc => 'The minimum level to display on the scren.',
        },
        log_file_level => {
            is => 'Text',
            default => 'info',
            valid_values => \@log_levels,
            doc => 'The minimum level to display in the log.',
        },
    ],
    has_optional => [
        log_file => {
            is => 'Text',
            doc => 'Path to log file.',
        },
    ],
    has_constant => [
        log_dispatch => {
            is => 'Log::Dispatch',
            doc => 'The Log::Dispatch object that is initialized based on options.',
            is_calculated => 1,
            calculate => q($self->log_dispatch_init),
        },
    ],
};

sub log_dispatch_init {
    my $self = shift;

    my $log = Log::Dispatch->new() || die;

    if ($self->screen) {
        $log->add(
            Log::Dispatch::Screen->new(
                name => 'Screen',
                min_level => $self->screen_level,
            )
        );
    }

    if ($self->log_file) {
        $log->add(
            Log::Dispatch::FileRotate->new(
                name => 'File',
                min_level => $self->log_file_level,
                filename => $self->log_file,
                mode => 'append',
                max => 5,
            )
        );
    }

    return $log;
}

# create object methods for each log level
for my $log_level (@log_levels) {
    $sub_ref = sub {
        my ($self, $message) = @_;

        chomp $message;
        $message = uc($log_level) . ": $message\n";

        return $self->log_dispatch->$log_level($message);
    };
    *$log_level = $sub_ref;
}

1;
