package Genome::Model::Tools::CommandLogReader;

use strict;
use warnings;
use Genome;
use IO::File;

class Genome::Model::Tools::CommandLogReader{
    is => 'Command',
    has =>[
        start_date => {
            is => 'Text',
            doc => "Logs written after the specified date (YYYY-MM-DD) will be included in the reader's output",
        },
    ],
    has_optional =>[
        output_file => {
            is => 'Text',
            doc => "Store log information in the specified file, defaults to STDOUT",
            default => "STDOUT",
        },
        end_date => {
            is => 'Text',
            doc => "Logs written before this date (YYYY-MM-DD) will not be included in the reader's output, defaults to current date"
        },
        group_by => {
            is => 'Text',
            valid_values => ["user","command"],
            default => "user",
            doc => "Groups output by user name or command name, defaults to user",
        },
    ],
};

sub help_brief {
    "Generates a report on command line usage of genome and gmt scripts";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This module generates a report on command line usage of genome scripts, grouping by either user name or command
EOS
}

sub log_attributes {
    my $self = shift;
    return (qw/ date time user command params/);
}

sub log_directory {
    my $self = shift;
    return "/gscuser/bdericks/command_logs/";
}

sub get_current_date {
    my $self = shift;
    my ($sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst) = localtime(time);
    return ($year + 1900, $month + 1, $day);
}

sub _sort_params {
    my $self = shift;
    my $params = shift;

    my @params = sort(split('--', $params));
    my $str;
    for my $p (@params) {
        next if length $p == 0;
        $p =~ s/^\s+|\s+$//g; # Remove leading and trailing spaces
        unless ($p =~ /=/) {  # Replace first space with = unless there's already an =
            $p =~ s/\s+/=/;
        }
        $str .= $p . "\t";
    }
    chop $str;
    return $str;
}

sub execute {
    my $self = shift;

    my ($start_year, $start_month, $start_day) = split(/-/, $self->start_date);
    if ($start_month =~ /^0/) {
        $start_month = substr $start_month, 1;
    }

    my ($end_year, $end_month, $end_day);
    if (defined $self->end_date) {
        ($end_year, $end_month, $end_day) = split(/-/, $self->end_date);
    }
    else {
        ($end_year, $end_month, $end_day) = $self->get_current_date();
    }

    my %info;
    my ($loop_year, $loop_month) = ($start_year, $start_month);
    my @log_columns = $self->log_attributes();
    LOG_FILE: while ($loop_year < $end_year or $loop_month <= $end_month) {
        my $log_file = $self->log_directory() . $loop_year . "-" . $loop_month . ".log";

        $loop_month++;
        if ($loop_month > 12) {
            $loop_month = 1;
            $loop_year++;
        }

        if (not -e $log_file) {
            $self->warning_message("Could not find $log_file, continuing.");
            next LOG_FILE;
        }

        my $log_svr = Genome::Utility::IO::SeparatedValueReader->create(
            input => $log_file,
            headers => \@log_columns,
            separator => "\t",
            is_regex => 1,
            ignore_extra_columns => 1,
        );

        LOG_LINE: while (my $line = $log_svr->next) {
            my ($log_year, $log_month, $log_day) = split(/-/, $line->{date}); 
            if ($log_year == $end_year and $log_month == $end_month and $log_day > $end_day) {
                last LOG_LINE;
            }

            if ($self->group_by eq "command"){

            }
            elsif ($self->group_by eq "user") {
                my $user = $line->{user};
                my $command = $line->{command};
                my $params = $self->_sort_params($line->{params});
                $info{$user}->{$command}->{$params}++;
            }
        }
        print Data::Dumper::Dumper \%info;
    }
}
1;

