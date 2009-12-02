package Genome::Report::Command::Email;

use strict;
use warnings;

use Genome;

class Genome::Report::Command::Email {
    is => 'Genome::Report::Command',
    has => [ 
    report_directory => { 
        is => 'Text', 
        doc => 'Directory location of the report.',
    },
    xsl_files => {
        is => 'Text',
        doc => 'Xslt file(s) to use to transform the report - separate by commas.',
    },
    to => {
        is => 'Text',
        doc => 'Report recipient(s) - separate by commas.',
    },
    ],
    has_optional => [
    from => {
        is => 'Text',
        doc => 'Sender of the email.  Defaults to user.',
    },
    replyto => {
        is => 'Text',
        doc => 'Reply to for email.  Defaults to user.',
    },
    ],
};

#< Helps >#
sub help_detail {
    return <<EOS;
    Transforms a report, then emails it.
EOS
}

#< Report >#
sub report {
    my $self = shift;

    unless ( $self->{_report} ) { 
        $self->{_report} = Genome::Report->create_report_from_directory($self->report_directory);
    }

    return $self->{_report};
}

#< Command >#
sub create { 
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    # Report
    unless ( $self->report ) {
        $self->error_message("Can't get report.  See above error.");
        $self->delete;
        return;
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $confirmation = Genome::Report::Email->send_report(
        report => $self->report,
        xslt_files => $self->xsl_files,
        to => $self->to,
        from => $self->from,
        replyto => $self->replyto,
    );

    unless ( $confirmation ) {
        $self->error_message("Can't email report.");
        return;
    }

    $self->status_message("Sent report.");

    return 1;
}

1;

#$HeadURL$
#$Id$
