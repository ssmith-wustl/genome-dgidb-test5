package Genome::Report::GeneratorCommand;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Temp;

class Genome::Report::GeneratorCommand {
    is => 'Command',
    is_abstract => 1,
    has_optional => [
        email => {
            is => 'Text',
            doc => 'Email the report to these recipients.  Separate by commas.',
        },
        save => {
            is => 'Text',
            doc => 'Save report to the directory.',
        },
        force_save => {
            is => 'Boolean',
            default_value => 0,
            doc => 'Force save the report.',
        },
    ],
};

#< Generate Report >#
sub _generate_report {
    my ($self, %params) = @_;

    # Generate report
    my $generator = Genome::Model::Report::Table->create(%params);
    my $report = $generator->generate_report;
    unless ( $report ) {
        $self->error_message("Can\'t generate report.");
        return;
    }

    return $report;
}

#< Functions >#
sub _execute_functions {
    my ($self, $report) = @_;

    die "No report given to execute functions." unless $report;
    
    # Save/email report
    for my $function (qw/ save email /) {
        next unless defined $self->$function;
        my $method = '_'.$function.'_report';
        $self->$method($report)
            or return;
    }
    return 1;
}

#< Save >#
sub _save_report {
    my ($self, $report) = @_;

    my $dir = $self->save;
    unless ( Genome::Utility::FileSystem->validate_existing_directory($dir) ) {
        $self->error_message("Can't save report because of problem with directory ($dir). See above error.");
        return;
    }

    unless ( $report->save($dir) ) {
        $self->error_message("Can't save report to directory ($dir).  See above errror.");
        return 1;
    }

    $self->_save_builds_dataset($report)
        or return;
    
    print "Saved report to ".$self->save."\n";

    return 1;
}

sub _save_builds_dataset {
    my ($self, $report) = @_;

    return $self->{_sv_file} if $self->{_sv_file};

    my $ds = $report->get_dataset('objects');
    unless ( $ds ) { # should not happen
        $self->error_message("Could not get builds datasets from report.");
        return;
    }

    my $dir = ( $self->save ? $self->save : File::Temp::tempdir(CLEANUP => 1) );
    my $file = $dir.'/builds.cvs';
    my $fh = Genome::Utility::FileSystem->open_file_for_writing($file)
        or return;
    my $svs = $ds->to_separated_value_string(',');
    unless ( $svs ) {
        $self->error_message("Can't get separated value string from build dataset");
        return;
    }
    $fh->print($svs);
    $fh->close;
    
    return $self->{_sv_file} = $file;
}

#< EMail >#
sub _email_report {
    my ($self, $report) = @_;

    my $file = $self->_save_builds_dataset($report)
        or return;

    my $confirmation = Genome::Report::Email->send_report(
        report => $report,
        to => $self->email,
        xsl_files => [ $report->generator->get_xsl_file_for_html ],
        attachments => [{
            description => 'Summary of Builds',
            disposition => "inline; filename=\"builds.csv\";\r\nContent-ID: <builds>",
            file => $file,
        }],
    );
    unless ( $confirmation ) {
        $self->error_message("Can't email report.");
        return;
    }

    print "Sent report to ".$self->email."\n";

    return 1;
}

1;

=pod

=head1 Name

Genome::Report::GeneratorCommand

=head1 Synopsis

Base command class for report generator commands.  Use this class as a base for yours.

=head1 Usage

=head1 Public Methods

=head2 generate_report

 my $report = $generator->generate_report
    or die;

=over

=item I<Synopsis>   Generates data and creates a Genome::Report

=item I<Arguments>  none

=item I<Returns>    Genome::Report

=back

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
