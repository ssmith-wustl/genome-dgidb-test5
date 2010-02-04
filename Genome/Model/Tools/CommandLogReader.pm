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
            doc => "Logs written after this date (YYYY-MM-DD) will be included in the reader's output.",
        },
    ],
    has_optional =>[
        report_type => {
            is => 'Text',
            valid_values => ["full","abbreviated","summary"],
            default => "summary",
            doc => "A full report lists every user/command/parameter combination and counts number of times each combination occurs. An abbreviated report excludes the parameter column. A summary report includes how many commands each user ran (if group by is user, does not include commands) or how many times a command was executed (if group by is command, does not include user). Defaults to summary."
        },
        output_file => {
            is => 'Text',
            doc => "Store log information in the specified file, defaults to STDOUT.",
            default => "STDOUT",
        },
        end_date => {
            is => 'Text',
            doc => "Logs written before this date (YYYY-MM-DD) will be included in the reader's output, defaults to current date."
        },
        group_by => {
            is => 'Text',
            valid_values => ["user","command"],
            default => "user",
            doc => "Groups output by user name or command name, defaults to user.",
        },
        print_headers => {
            is => 'Boolean',
            default => 1,
            doc => "Print column headers on first line of output.",
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
    return "/gsc/var/log/genome/command_line_usage/";
}

sub output_attributes {
    my $self = shift;
    if ($self->group_by eq "user") {
        if ($self->report_type eq "full") {
            return (qw/ user command params times_called/);
        }
        elsif ($self->report_type eq "abbreviated") {
            return (qw/ user command times_called/);
        }
        elsif ($self->report_type eq "summary") {
            return (qw/ user num_commands/);
        }
    }
    elsif ($self->group_by eq "command") {
        if ($self->report_type eq "full") {
            return (qw/ command user params times_called/);
        }
        elsif ($self->report_type eq "abbreviated") {
            return (qw/ command user times_called/);
        }
        elsif ($self->report_type eq "summary") {
            return (qw/ command times_called/);
        }
    }
    else {
        $self->error_message("Unknown group by attribute or report type, unable to provide column headers");
        return;
    }
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
    return unless @params;

    my $str;
    for my $p (@params) {
        next if length $p == 0;
        $p =~ s/^\s+|\s+$//g; # Remove leading and trailing spaces
        unless ($p =~ /=/) {  # Replace first space with = unless there's already an =
            $p =~ s/\s+/=/;
        }
        $str .= $p . " ";
    }
    chop $str;
    return $str;
}

sub _create_file {
    my ($self, $output_file) = @_;
    my $output_fh;

    if (-e $output_file) {
        $self->warning_message("found previous output file, removing $output_file");
        unlink $output_file;
        if (-e $output_file) {
            die "failed to remove previous file: $! ($output_file)";
        }
    }
    $output_fh = IO::File->new("> $output_file");
    unless ($output_fh) {
        die "Can't open file ($output_file) for writing: $!";
    }

    return $output_fh;
}

sub execute {
    my $self = shift;

    my ($start_year, $start_month, $start_day) = split(/-/, $self->start_date);
    unless (defined $start_year and defined $start_month and defined $start_day) {
        $self->error_message("Trouble parsing start date, exiting");
        return;
    }

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

        unless (-e $log_file) {
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

            my $user = $line->{user};
            my $command = $line->{command};
            my $params = $self->_sort_params($line->{params});
            unless (defined $params) {
                if ($self->group_by eq "command") {
                    $info{$command}->{$user}->{"none"}++;
                }
                elsif ($self->group_by eq "user") {
                    $info{$user}->{$command}->{"none"}++;
                }
            }
            else {
                if ($self->group_by eq "command"){
                    $info{$command}->{$user}->{$params}++;
                }
                elsif ($self->group_by eq "user") {
                    $info{$user}->{$command}->{$params}++;
                }
            }
        }
    }

    # Print to output file, tab delimited
    # Format (grouped by user): user command params(space delimited) times_called
    # Format (grouped by command): command user params(space delimited) times_called
    my $output_fh;
    my $output_file = $self->output_file;
    if ($self->output_file =~ /STDOUT/i) {
        $output_fh = 'STDOUT';
    }
    else {
        $output_fh = $self->_create_file($output_file);
    }

    if ($self->print_headers) {
        $output_fh->print(join("\t", $self->output_attributes) . "\n");
    }

    for my $group (sort keys %info) {
        if ($self->report_type eq "summary") {
            my $sum = 0;
            for my $subgroup (sort keys %{$info{$group}}) {
                for my $params (keys %{$info{$group}->{$subgroup}}) {
                    $sum += $info{$group}->{$subgroup}->{$params};
                }
            }
            $output_fh->print($group . "\t");
            $output_fh->print($sum . "\n");
        }

        else {
            for my $subgroup (sort keys %{$info{$group}}) {
                if ($self->report_type eq "full") {
                    for my $params (keys %{$info{$group}->{$subgroup}}) {
                        $output_fh->print($group . "\t");
                        $output_fh->print($subgroup . "\t");
                        $output_fh->print($params . "\t");
                        $output_fh->print($info{$group}->{$subgroup}->{$params} . "\n");
                    }
                }

                elsif ($self->report_type eq "abbreviated") {
                    my $sum = 0;
                    for my $params (keys %{$info{$group}->{$subgroup}}) {
                        $sum += $info{$group}->{$subgroup}->{$params};
                    }
                    $output_fh->print($group . "\t");
                    $output_fh->print($subgroup . "\t");
                    $output_fh->print($sum . "\n");
                }
            }
        }

    }
}
1;

