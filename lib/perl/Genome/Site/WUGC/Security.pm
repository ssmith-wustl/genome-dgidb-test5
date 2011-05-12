
package Genome::Site::WUGC::Security;

use File::Basename;
use DateTime;
use IO::File;
use Sys::Hostname;

# Get info about command and write to log file.
# Send error information if log file isn't found or can't be accessed, which is usually
# a good indication that there are disk issues afoot.
sub log_command {
    my @argv = @ARGV;
    my $command = basename($0) . " ";
    while (@argv) {
        last unless defined $argv[0] and $argv[0] !~ /^-/;
        $command .= (shift @argv) . " ";
    }

    my $params = join(" ", @argv);
    my $dt = DateTime->now;
    $dt->set_time_zone('America/Chicago');
    my $date = $dt->ymd;
    my $time = $dt->hms;
    my $host = hostname;

    my $log_dir = "/gsc/var/log/genome/command_line_usage/" . $dt->year . "/";
    my $log_file = $dt->month . "-" . $dt->day . ".log";
    my $log_msg = join("\t", $date, $time, Genome::Sys->username, $command, $params);

    unless (-e $log_dir and -d $log_dir) {
        mkdir $log_dir;
        chmod(0777, $log_dir);
    }

    my $log_path = $log_dir . $log_file;
    my $log_fh = IO::File->new($log_path, 'a');
    unless ($log_fh) {
        print STDERR "Could not get file handle for log file at $log_path, command execution will continue!\n";

        my $email_msg = "User: " . Genome::Sys->username . "\n" .
                        "Date: $date\n" .
                        "Time: $time\n" .
                        "Host: $host\n" .
                        "Command: $command\n" .
                        "Could not write to log file at $log_path : $!\n";

        App::Mail->mail(
            To      => 'bdericks@genome.wustl.edu',
            From    => Genome::Config->user_email,
            Subject => "Error writing to log file",
            Message => $email_msg
        );
        return;
    }

    flock($log_fh, 2);
    chmod(0666, $log_path) unless -s $log_path;
    print $log_fh "$log_msg\n";
    close $log_fh;
    return;
}


sub email_usage_info {    
    my $class = shift;
    my $to = shift;

    return unless ($to);

    my $command = $0 || 'unknown command';
    my @argv = @ARGV;

    my $user = getpwuid($<) || 'unknown-user';
    my $host = Sys::Hostname::hostname() || 'unknown-hostname';
    my $time = localtime(time) || 'Unknown Time';
    my $package = (caller)[0] || 'Unknown Package';;
    my $program = join(' ', $command, @argv) || 'Unknown Program';

    my $from = $user . '@genome.wustl.edu';
    my $subject = "$user\@$host used $package";
    my $message = join("\n",
        "    User: $user",
        "    Host: $host",
        "    Time: $time",
        " Package: $package",
        " Program: $program"
    );

    App::Mail->mail(
        To      => $to,
        From    => $from,
        Subject => $subject,
        Message => $message,
    );

    return 1;
}


# Check if a svn repo is being used and contact apipe
sub check_for_svn_repo {
    my $dir = $INC{"Genome.pm"};
    $dir =~ s/Genome.pm//;
   
    if (-e "$dir/.svn" or glob("$dir/Genome/*/.svn")) {
        my $email_msg = "User: " . Genome::Sys->username . "\n" .
                        "Working directory: $dir\n" .
                        "The current working directory contains a .svn directory, which I'm assuming means \n" .
                        "that this user is working out of an svn repository. Please contact the user to \n" .
                        "confirm and provide any assistance to ease their transition to git.\n";

        App::Mail->mail(
            To => "apipebulk\@genome.wustl.edu",
            From => Genome::Config->user_email,
            Subject => "SVN Repo In Use!",
            Message => $email_msg,
        );

        return;
    }
}

1;

