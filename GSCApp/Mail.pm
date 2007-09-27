# Customize App::Mail for GSC
# Copyright (C) 2004 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# set package name for module
package GSCApp::Mail;

=pod

=head1 NAME

GSCApp::Mail - customize mail configuration and execution for GSC

=head1 SYNOPSIS

To submit a mail message from an application:

    use GSCApp;

    App::Mail->mail(To => 'you@your.com', From => 'me@mine.com',
                    Subject => 'the subject', Message => 'hi there');

The daemon/cron job that actually sends the mail should do this:

    use GSCApp;

    App::Mail->smail;

=head1 DESCRIPTION

This module provides methods to configure a mail gateway, issue
requests for sending mail, and actually sending mail.

=cut

# set up package
require 5.6.0;
use warnings;
use strict;
our $VERSION = '0.8';
use App::Mail;

# configure App::Mail
App::Mail->config
(
    mqueue => (($^O eq 'MSWin32' || $^O eq 'cygwin')
               ? '//winsvr.gsc.wustl.edu/var/spool/mqueue'
               : '/gsc/var/spool/mqueue'),
    ext => '.mailhash',
);

# switch over to App::Mail to implement mail and smail
package App::Mail;
use warnings;
use strict;
use base qw(App::MsgLogger);
use Data::Dumper;
use IO::File;
use IO::Dir;
use Mail::Sendmail;
use Sys::Hostname;
use App::Name;

=pod

=head2 METHODS

These methods request and send mail.

=over 4

=cut

# check headers in mail hash
sub _header_check
{
    my $class = shift;
    my (%mail) = @_;

    # loop through the headers to check
    foreach my $k qw(To From Subject Message)
    {
        # make sure it exists
        if (exists($mail{$k}))
        {
            $class->debug_message("mail key $k exists", 4);
        }
        else
        {
            $class->error_message("required mail key $k does not exist");
            return;
        }

        # make sure it is set with something
        if ($mail{$k})
        {
            $class->debug_message("mail key $k is set: $mail{$k}", 4);
        }
        else
        {
            $class->error_message("required mail key $k not set");
            return;
        }
    }

    return 1;
}

# do not complain that these subroutines are redefined
no warnings 'redefine';

=pod

=item mail

  App::Mail->mail(%mail);

This method expects a hash conforming to that required by
Mail::Sendmail (see L<Mail::Sendmail>) with a few exceptions:

=over 6

=item .

Keys ARE case-sensitive.

=item .

Only the Message key is allowed for the mesasge body text
(Mail::Sendmail accepts several options).

=back

It then creates a file in the mail queue directory so that C<smail>
can send it out.

=cut

sub mail
{
    my $class = shift;
    my (%mail) = @_;

    if ($App::Mail::DISABLE_FOR_TESTING) {
	push (@App::Mail::SPOOLED_TESTING_MAIL, \%mail);
	return 1;
    }

    # set originating host and user header
    my $host = hostname;
    if ($host)
    {
        $class->debug_message("hostname is $host", 3);
    }
    else
    {
        $class->warning_message("choosing arbitrary host name");
        $host = 'gschost';
    }
    my ($login, $name);
    if ($^O eq 'MSWin32' || $^O eq 'cygwin')
    {
        $login = 'winguest';
        $name = 'Generic Windows User';
    }
    else
    {
        ($login, $name) = (getpwuid($<))[0, 6];
        $login ||= 'nobody';
        $name ||= 'Nobody';
    }
    $mail{'X-GSCApp-Mail-Sender'} = "$login\@$host";

    # set from header if is is not set
    if (!exists($mail{From}) || !$mail{From})
    {
        $mail{From} = qq("$name" <$login\@watson.wustl.edu>);
    }

    # check headers
    if ($class->_header_check(%mail))
    {
        $class->debug_message("mail headers are ok", 3);
    }
    else
    {
        # warning already given
        return;
    }

    # check email addresses
    foreach my $header qw(To From Cc Bcc)
    {
        if (exists($mail{$header}))
        {
            my @addresses = split(m/\s*,\s*/, $mail{$header});
            foreach my $add (@addresses)
            {
                if ($add =~ m/\@/)
                {
                    $class->debug_message("address is qualified: $add", 4);
                }
                elsif ($add =~ m/[^-\w.]/)
                {
                    $class->error_message("address is not qualified and is not "
                                          . "simple enough to fix: $add");
                    return;
                }
                else
                {
                    # qualify simple addresses
                    $add .= '@watson.wustl.edu';
                }

                # make sure email address looks valid
                if ($add =~ m/[-.+\w]+@[-.\w]+/)
                {
                    $class->debug_message("address looks valid: $add", 4);
                }
                else
                {
                    $class->error_message("address does not appear to be "
                                          . "valid: $add");
                    return;
                }
            }
            # replace original with new list
            $mail{$header} = join(', ', @addresses);
        }
    }


    # create unique file name
    my $mqueue = App::Mail->config('mqueue');
    if ($mqueue)
    {
        $class->debug_message("mqueue is $mqueue", 3);
    }
    else
    {
        $class->error_message("mqueue directory not defined");
        return;
    }
    if (-d $mqueue)
    {
        $class->debug_message("mqueue directory $mqueue exists", 3);
    }
    else
    {
        $class->error_message("mqueue directory $mqueue does not exist");
        return;
    }

    my $ext = App::Mail->config('ext');
    if ($ext)
    {
        $class->debug_message("mail extension is $ext", 3);
    }
    else
    {
        $class->error_message("mail file extension not set");
        return;
    }
    my $file = "$mqueue/" . App::Name->prog_name . "-$host-$$";
    while (-e "$file$ext")
    {
        $file .= 'x';
    }
    $file .= $ext;

    # set permissive umask
    my $umask = umask;
    eval
    {
        umask(0000);
    };

    # open the file for writing
    my $fh = IO::File->new(">$file");
    if (defined($fh))
    {
        $class->debug_message("opened file $file for writing", 3);
    }
    else
    {
        $class->error_message("failed to open file $file for writing: $!");
        umask($umask) if $umask;
        return;
    }

    # create dumper object
    my $dd = Data::Dumper->new([\%mail], ['mail_hash_ref']);
    $fh->print($dd->Dump)
        or die("failed to write to file $file");
    $fh->close;

    # change umask back
    umask($umask) if $umask;

    return 1;
}

=pod

=item smail

  App::Mail->smail;

This method scans the mqueue directory for mail hash files.  For each
one it finds, it evals the contents of the file and sends it using
Mail::Sendmail.  If a massive failure occurs, C<undef> is returned.
If there are any failures sending mail, it returns less than zero.  If
there are no failures, it returns the number of mails sent (which may
be zero).

Note that in applications you do not call the C<smail> method.  At the
GSC, there is a cron job on cron1 that is run every five minutes and
calls C<smail>.

=cut

sub smail
{
    my $class = shift;

    # get mqueue directory
    my $mqueue = App::Mail->config('mqueue');
    if ($mqueue)
    {
        $class->debug_message("mail queue directory is $mqueue", 3);
    }
    else
    {
        $class->error_message("mail queue directory is not set");
        return;
    }
    # get mail extension
    my $ext = App::Mail->config('ext');
    if ($ext)
    {
        $class->debug_message("mail extension is $ext", 3);
    }
    else
    {
        $class->error_message("mail extension is not set");
        return;
    }

    # open directory
    my $dh = IO::Dir->new($mqueue);
    if (defined($dh))
    {
        $class->debug_message("opened directory $mqueue", 3);
    }
    else
    {
        $class->error_message("failed to open directory $mqueue: $!");
        return;
    }

    # tell Mail::Sendmail not to do MIME encoding to avoid bug in
    # MIME::QuotedPrint that loses periods
    $Mail::Sendmail::mailcfg{mime} = 0;

    # loop through the contents of the directory
    my ($sent, $fail) = (0, 0);
    my @files = $dh->read;
    foreach my $file (@files)
    {
        next unless $file =~ m/$ext$/;

        my $fh = IO::File->new("<$mqueue/$file");
        if (defined($fh))
        {
            $class->debug_message("opened file $file for reading", 4);
        }
        else
        {
            $class->error_message("failed to open file $file for reading: $!");
            ++$fail;
            next;
        }

        # read the contents of the file
        my $mail_hash_ref_dump = join('', $fh->getlines);
        $fh->close;

        # eval the dump
        my $mail_hash_ref;
        eval($mail_hash_ref_dump);

        # allow us to reference mail hash variable indirectly
        if (ref($mail_hash_ref) eq 'HASH')
        {
            $class->debug_message("dumper ref is a hash ref", 4);
        }
        else
        {
            $class->error_message("dumper ref is not a hash ref");
            ++$fail;
            next;
        }

        # check the mail headers
        if ($class->_header_check(%$mail_hash_ref))
        {
            $class->debug_message("all required mail headers present", 4);
        }
        else
        {
            $class->error_message("mail hash in $file does not have all "
                                  . "required mail headers");
            ++$fail;
            next;
        }

        # very verbose debugging information
        $class->debug_message("mail hash: " . Dumper($mail_hash_ref), 6);

        # send the mail
        if (sendmail(%$mail_hash_ref))
        {
            $class->debug_message("sent mail: $Mail::Sendmail::log", 5);
        }
        else
        {
            $class->error_message("failed to send mail: $Mail::Sendmail::error");
            ++$fail;
            next;
        }

        # remove the file
        if (unlink("$mqueue/$file"))
        {
            $class->debug_message("removed mail queue file $file", 4);
        }
        else
        {
            $class->error_message("failed to remove file $mqueue/$file: $!");
            ++$fail;
            next;
        }

        ++$sent;
    }

    # close the directory
    $dh->close;

    return ($fail) ? -$fail : $sent;
}

1;
__END__

=pod

=back

=head1 BUGS

Report bugs to <software@watson.wustl.edu>.

=head1 SEE ALSO

App(3), App::Mail(3), GSCApp(3), Mail::Sendmail(3), perlfunc(1)

=head1 AUTHOR

David Dooling <ddooling@watson.wustl.edu>

=cut

# $Header$
