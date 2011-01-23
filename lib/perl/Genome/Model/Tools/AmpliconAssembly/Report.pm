package Genome::Model::Tools::AmpliconAssembly::Report;

use strict;
use warnings;

use Carp 'confess';
use Data::Dumper 'Dumper';

my %REPORT_INFO = (
    stats => { param_names => [qw/ /], },
    compare => { param_names => [qw/ /], },
    #composition => { param_names => [qw/ /], },
);
class Genome::Model::Tools::AmpliconAssembly::Report {
    is => 'Command',
    #is => 'Genome::Model::Tools::AmpliconAssembly',
    has => [
    directories => {
        is => 'ARRAY',
        doc => 'Directories of existing amplicon assemblies. Separate by commas.',
    },
    report => {
        is => 'Text',
        doc => 'The report to generate: '.join(',', valid_reports()),
    },
    _amplicon_assemblies => {
        is => 'ARRAY',
        doc => 'Amplicon assemblies retrieved from the directories.'
    },
    ],
    has_optional => [
    report_params => {
        is => 'Text',
        doc => 'A quoted string of parameters to generate the report. Indicate by using a minus "-" infront of each parameter name, followed by space and the value.  Valid parameters for reports: '.reports_and_param_names_as_string(),
    },
    report_directory => {
        is => 'Text',
        #default_value => '.',
        doc => 'The directory to save the report, transformed report and/or datasets'
    },
    print_dataset => {
        is => 'Text',
        default_value => 0,
        doc => 'Print this particular dataset to the screen.',
    },
    print_datasets => {
        is => 'Text',
        default_value => 0,
        doc => 'Print all datasets to the screen.',
    },
    print_report => {
        is => 'Boolean',
        default_value => 0,
        doc => 'Print the report XML to the screen.',
    },
    save_datasets => {
        is => 'Boolean',
        default_value => 0,
        doc => 'Save all the datasets of the report as CSV.',
    },
    save_report => {
        is => 'Boolean',
        default_value => 0,
        doc => 'Save the report XML.',
    },
    ],
};

#< Reports >#
sub valid_reports {
    return keys %REPORT_INFO;
}

sub report_param_names {
    my $report = shift;
    confess "No report given to get report param names." unless $report;
    return @{$REPORT_INFO{$report}->{param_names}};
}

sub reports_and_param_names_as_string {
    return join(
        ', ',
        map { $_.' ('.join(', ', report_param_names($_)).')'} valid_reports()
    );
}

sub report_generator_class {
    return 'Genome::AmpliconAssembly::Report::'.ucfirst($_[0]->report);
}

#< Functions >#
sub functions {
    return (qw/ print_report print_dataset print_datasets save_report save_datasets /);
}

#< Helps >#
sub help_brief {
    return 'Generate (and operate on) reports';
}

sub help_detail {
    return sprintf(
        'This command will generate and operate on a %s report. The functions that can be done are: %s. See above for function documantation. Any files saved will be in the report directory plus the report name.',
        $_[0]->command_name_brief,
        join(', ', $_[0]->functions),
    );
}

sub help_synopsis {
}

#< Command >#
sub sub_command_sort_position { 50; }

sub create {
    my ($class, %params) = @_;

    unless ( $params{directories} ) {
        $class->error_message("No directories given to get amplicon assemblies to generate report.");
        return;
    }

    unless ( ref $params{directories} ) {
        $params{directories} = [ split(',', $params{directories}) ];
    }

    my $self = $class->SUPER::create(%params)
        or return;

    my @amplicon_assemblies;
    for my $directory ( @{$self->directories} ) {
        push @amplicon_assemblies, Genome::AmpliconAssembly->create(directory => $directory)
            or return;
    }
    $self->_amplicon_assemblies(\@amplicon_assemblies);

    # If no functions, print report
    unless ( grep { $self->$_ } functions() ) {
        $self->print_report(1);
    }

    # Report dir
    if ( $self->report_directory ) { # savin sumpin
        # validate
        unless ( Genome::Sys->validate_existing_directory($self->report_directory) ) {
            $self->error_message("No report was indicated to generate");
            $self->delete;
            return;
        }

        # save both report and datasets if none indicated
        my @save_functions = grep { m#save# } functions();
        unless ( grep { $self->$_ } @save_functions ) {
            for my $function ( @save_functions ) {
                $self->$function(1);
            }
        }
    }

    # Report
    my $report = $self->report;
    unless ( $report ) {
        $self->error_message("No report was indicated to generate");
        $self->delete;
        return;
    }

    unless ( grep { $report eq $_ } valid_reports() ) {
        $self->error_message("Invalid report ($report) was to generate");
        $self->delete;
        return;
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $generator = $self->_create_report_generator
        or return;
    my $report = $generator->generate_report;
    unless ( $report ) {
        $self->error_message(
            sprintf(
                "Can't generate %s for amplicon assembly in directory (%s).",
                $self->command_name_brief,
                $self->directory,
            )
        );
        return;
    }

    for my $function ( $self->functions ) {
        next unless $self->$function;
        my $method = '_'.$function;
        $self->$method($report)
            or return;
    }

    return 1;
}

#< Generator and Report >#
sub _create_report_generator {
    my $self = shift;

    my $class = $self->report_generator_class;
    my $generator = $class->create(
        amplicon_assemblies => $self->_amplicon_assemblies,
        $self->_params_for_genertor,
    );
    unless ( $generator ) {
        $self->error_message(
            sprintf(
                "Can't create %s generator for amplicon assembly in directory (%s).",
                $self->command_name_brief,
                $self->directory,
            )
        );
        return;
    }

    return $generator;
}

sub _params_for_genertor {
    my $self = shift;
    
    my $param_string = $self->report_params;
    return unless $param_string;

    my %params = Genome::Utility::Text::param_string_to_hash($param_string);
    unless ( %params ) {
        $self->error_message("Can't convert report param string ($param_string).  See above error.");
        return;
    }

    return %params;
}

sub _print_report {
    my ($self, $report) = @_;

    print $report->xml_string;
}

sub _print_dataset {
    my ($self, $report) = @_;

    my $csv = $self->_get_csv_for_dataset($report, $self->print_dataset)
        or return;
    
    return print $csv;
}

sub _print_datasets {
    my ($self, $report) = @_;

    my $directory = $self->report_directory.'/'.$report->name_to_subdirectory($report->name);

    my @dataset_names = $report->get_dataset_names;
    unless ( @dataset_names ) {
        $self->error_message("No datasets found in report");
        return;
    }

    for my  $name ( @dataset_names ) {
        my $csv = $self->_get_csv_for_dataset($report, $name)
            or return;
        print "Dataset: $name\n$csv\n";
    }

    return 1;
}

sub _save_report {
    my ($self, $report) = @_;

    unless ( $report->save($self->report_directory, 1) ) {
        $self->error_message("Can't save report. See above error");
        return;
    }

    $self->status_message("Saved report XML to ".$self->report_directory);
    
    return 1;
}

sub _save_datasets {
    my ($self, $report) = @_;

    my $directory = $self->report_directory.'/'.$report->name_to_subdirectory($report->name);

    my @dataset_names = $report->get_dataset_names;
    unless ( @dataset_names ) {
        $self->error_message("No datasets found in report");
        return;
    }

    for my  $name ( @dataset_names ) {
        my $csv = $self->_get_csv_for_dataset($report, $name)
            or return;
        my $file = $directory."/$name.csv";
        unlink $file if -e $file;
        my $fh = Genome::Sys->open_file_for_writing($file)
            or return;
        $fh->print($csv);
        $fh->close;
    }

    $self->status_message("Saved datasets to $directory");

    return 1;
}

sub _get_csv_for_dataset {
    my ($self, $report, $name) = @_;

    my ($csv) = $report->get_datasets_by_name_as_separated_value_string($name, ',');
    unless ( $csv ) {
        $self->error_message(
            sprintf(
                "Can't get dataset (%s) from report (%s).",
                $name,
                $self->report,
            )
        );
        return;
    }

    return $csv;
}

1;

#$HeadURL$
#$Id$
