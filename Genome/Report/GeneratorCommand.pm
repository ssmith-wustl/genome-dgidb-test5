package Genome::Report::GeneratorCommand;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Basename;
require File::Temp;

class Genome::Report::GeneratorCommand {
    is => 'Command',
    has_optional => [
        print_xml => {
            is => 'Boolean',
            doc => 'Print the report XML to the screen (STDOUT).',
        },
        print_datasets => {
            is => 'Boolean',
            doc => 'Print the datasets as cvs to the screen (STDOUT). Default will be to print all datasets. Indicate specific datasets with the "datasets" option.',
        },
        datasets => {
            is => 'Text',
            doc => 'Datasets to print, save or email. Use with functions print_datasets, save or email.  Separate by commas.  To indicate all datasets, use optiona "all_datasets".',
        },
        all_datasets => {
            is => 'Text',
            doc => 'Print, save or email all datasets in the report. Use with functions print_datasets, save or email.',
        },
        email => {
            is => 'Text',
            doc => 'Email the report to these recipients.  Separate by commas.',
        },
        save => {
            is => 'Text',
            doc => 'Save report to this directory.',
        },
        force_save => {
            is => 'Boolean',
            doc => 'Force save the report, if one already exists.',
        },
        # private
        _dataset_names => {
            is => 'Array',
        },
        _datasets_csv => {
            is => 'Hash',
        },
        _datasets_files => {
            is => 'Hash',
        },
    ],
};

#< Generate Report >#
sub _generate_report_and_execute_functions {
    my ($self, %params) = @_;

    # Generate report
    my $generator = Genome::Model::Report::Table->create(%params);
    my $report = $generator->generate_report;
    unless ( $report ) {
        $self->error_message("Can\'t generate report.");
        return;
    }

    my @functions = (qw/ print_xml print_datasets email save /);
    my @selected_functions = grep { $self->$_ } @functions;
    unless ( @selected_functions ) {
        $self->print_datasets(1);
        @selected_functions = (qw/ print_datasets /);
    }

    $self->_resolve_dataset_names($report)
        or return;
    
    for my $function ( @selected_functions ) {
        my $method = '_'.$function;
        $self->$method($report)
            or return;
    }

    return $report;
}

sub _resolve_dataset_names {
    my ($self, $report) = @_;

    if ( $self->print_datasets and not $self->datasets ) {
        $self->all_datasets(1);
    }

    if ( $self->all_datasets ) {
        my @dataset_names = $report->get_dataset_names;
        unless ( @dataset_names ) {
            $self->error_message("Indicated to use all datasets (for print_xml, print_datasets, email save), but this report does not have any.");
            return;
        }
        $self->_dataset_names(\@dataset_names);
    }
    elsif ( $self->datasets ) {
        $self->_dataset_names([ split(',', $self->datasets) ]);
    }

    return 1;
}

#< Print XML >#
sub _print_xml {
    my ($self, $report) = @_;

    return print $report->xml_string;
}

#< Print Datasets (default) >#
sub _print_datasets {
    my ($self, $report) = @_;

    my $datasets_csv = $self->_datasets_to_csv($report)
        or return;

    for my $csv ( values %$datasets_csv ) {
        print $csv;
    }

    return 1;
}

sub _datasets_to_csv {
    my ($self, $report) = @_;

    return $self->_datasets_csv if $self->_datasets_csv;

    my $dataset_names = $self->_dataset_names;
    unless ( $dataset_names ) {
        $self->_datasets_csv({});
        return $self->_datasets_csv;
    }
    
    my %datasets_csv;
    for my $name ( @$dataset_names ) {
        my $ds = $report->get_dataset($name);
        unless ( $ds ) { # bad
            $self->error_message("Could not get dataset ($name) from report.");
            return;
        }

        my $csv = $ds->to_separated_value_string(',');
        unless ( $csv ) {
            $self->error_message("Can't get separated value string from build dataset");
            return;
        }
        $datasets_csv{$name} = $csv;
    }

    return $self->_datasets_csv(\%datasets_csv);
}

#< Save >#
sub _save {
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

    $self->_save_datasets($report)
        or return;

    print "Saved report to ".$self->save."\n";

    return 1;
}

sub _save_datasets {
    my ($self, $report) = @_;

    return $self->_datasets_files if $self->_datasets_files;

    my $datasets_csv = $self->_datasets_to_csv($report)
        or return;

    my $dir = ( $self->save ? $self->save : File::Temp::tempdir(CLEANUP => 1) );
    my %datasets_files;
    for my $name ( keys %$datasets_csv ) {
        my $file = sprintf('%s/%s.csv', $dir, $name);
        my $fh = Genome::Utility::FileSystem->open_file_for_writing($file)
            or return;
        $fh->print($datasets_csv->{$name});
        $fh->close;
        $datasets_files{$name} = $file;
    }

    return $self->_datasets_files(\%datasets_files);
}

#< EMail >#
sub _email {
    my ($self, $report) = @_;

    my $datasets_files = $self->_save_datasets($report)
        or return;

    my @attachments;
    for my $name ( keys %$datasets_files ) {
        my $basename = File::Basename::basename($datasets_files->{$name});
        push @attachments, {
            description => $name,
            disposition => "inline; filename=\"$basename\";\r\nContent-ID: <$name>",
            file => $datasets_files->{$name},
        };
    }

    my $confirmation = Genome::Report::Email->send_report(
        report => $report,
        to => $self->email,
        xsl_files => [ $report->generator->get_xsl_file_for_html ],
        attachments => \@attachments,
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
