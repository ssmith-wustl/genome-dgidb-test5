package Genome::Model::Command::Report::List;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Term::ANSIColor;
require Text::Wrap;
require Genome::Model::Report;

class Genome::Model::Command::Report::List {
    is => 'Command',
    has_optional => [
        type_name => {
            is => 'Text', 
            is_input => 1,
            doc => 'List reports for this model sub type only' 
        },
        build => { 
            is => 'Genome::Model::Build', 
            id_by => 'build_id',
            doc => 'The build of a genome model to check reports',
        },
        build_id => {
            is => 'Integer',
            is_input => 1,
            doc => 'The build id of a genome model to check reports',
        },
    ],
};

###################################################

sub help_brief {
    return 'Lists reports for model type names';
}

sub help_synopsis {
    return <<"EOS"
List all models' available reports
 genome model report list

List reports for reference alignment models
 genome model report list --type_name 'reference alignment'

List reports for a build
 genome model report list --build-id 96426120

EOS
}

sub help_detail {
    return help_brief();
}

###################################################

sub execute {
    my $self = shift;

    my $method;
    if ( $self->type_name ) {
        $method = '_list_reports_for_type_name';
    }
    elsif ( $self->build_id ) {
        $method = '_list_reports_for_build';
    }
    else {
        $method = '_list_reports_for_all_type_names';
    }
    
    return $self->$method;
}

sub _list_reports_for_type_name {
    my $self = shift;

    $self->_print_header_for_type_names
        or return;

    return $self->_print_reports_for_type_name($self->type_name);
}

sub _list_reports_for_all_type_names {
    my $self = shift;

    my @type_names = Genome::Model::Command::get_model_type_names()
        or return; # this errors if none found

    $self->_print_header_for_type_names
        or return;
    
    for my $type_name ( @type_names ) {
        $self->_print_reports_for_type_name($type_name)
            or return;
    }

    return 1;
}

sub _print_header_for_type_names {
    my $self = shift;

    return print Term::ANSIColor::colored('Reports for Model Type Names', 'bold')."\n";
}

sub _print_reports_for_type_name {
    my ($self, $type_name) = @_;

    my @report_names = Genome::Model::Report::get_report_names_for_type_name(
        $type_name
    );

    return print Text::Wrap::wrap(
        ' ',
        '  ',
        Term::ANSIColor::colored($type_name, 'red'), 
        "\n",
        ( @report_names ? join("\n", @report_names) : 'none' ),
    )."\n";
}

#< Build's Reports >#
sub _list_reports_for_build {
    my $self = shift;
    
    my $type_name = $self->build->model->type_name;
    my @availble_report_generators = Genome::Model::Report::get_report_names_for_type_name($type_name);

    unless ( @availble_report_generators ) { # ok
        print "Model type ($type_name) does not have any reports.\n";
        return 1;
    }
    
    my %reports = map { $_ => [] } @availble_report_generators;
    for my $report ( $self->build->reports ) {
        my ($report_subclass) = $report->get_generator =~ m#::([\w\d]+)$#;
        my $report_generator = Genome::Utility::Text::camel_case_to_string($report_subclass);
        push @{$reports{$report_generator}}, $report;
    }

    #print Dumper([keys %reports]); print $self->build->resolve_reports_directory,"\n";

    $self->_print_header_for_build
        or return;

    for my $report_name ( @availble_report_generators ) {
        $self->_print_reports($report_name, $reports{$report_name})
            or return;
    }

    return 1;
}

sub _print_header_for_build {
    my $self = shift;

    return print(
        Term::ANSIColor::colored(
            sprintf('Reports for %s Build (<Id> %s)', 
                join('', map { ucfirst } split(/\s+/, $self->build->model->type_name)),
                $self->build->id
            ), 
            'bold'
        ),
        "\n",
    );
}

sub _print_reports {
    my ($self, $report_name, $reports) = @_;

    my @strings = Term::ANSIColor::colored(sprintf('%s (%s)', $report_name, scalar(@$reports)), 'red');
    
    if ( @$reports ) {
        for my $report ( @$reports ) {
            push @strings, sprintf("%s (%s)", $report->name, $report->get_date);
        }
    }
    else {
        push @strings, "None";
    }

    return print Text::Wrap::wrap(' ', '  ', join("\n", @strings))."\n";
}

1;

#$HeadURL$
#$Id$
