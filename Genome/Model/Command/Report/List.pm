package Genome::Model::Command::Report::List;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Term::ANSIColor;
require Text::Wrap;

class Genome::Model::Command::Report::List {
    is => 'Command',
    #is => 'Genome::Model::Command::Report',
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
    return 'Lists reports for builds or model types';
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

    my @type_names = $self->get_model_type_names
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

    my @report_names = $self->get_report_names_for_type_name($type_name);

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
    my @availble_report_generators = $self->get_report_names_for_type_name($type_name);

    unless ( @availble_report_generators ) { # ok
        print "Model type ($type_name) does not have any reports.\n";
        return 1;
    }
    
    my %reports = map { $_ => [] } @availble_report_generators;
    for my $report ( $self->build->reports ) {
        my ($report_subclass) = $report->get_generator =~ m#::([\w\d]+)$#;
        my @words = $report_subclass =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/g;
        my $report_generator = join(' ', map { lc } @words);
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

#< Public Methods for Getting Models and Reports Subclasses and Such >#
sub get_inc_directory_for_class {
    my ($self, $class) = @_;

    my $module = _class_to_module($class);
    my $directory = $INC{$module};
    $directory =~ s/$module//;

    return $directory;
}

sub get_model_subclasses {
    my $self = shift;

    # return if no models dir
    my $directory = $self->get_inc_directory_for_class(__PACKAGE__);
    my $model_directory = "$directory/Genome/Model";
    unless ( -d $model_directory ) { # not ok
        confess "Model directory ($model_directory) does not exist!\n";
    }

    my @model_subclasses;
    for my $model_module ( glob("$model_directory/*pm") ) {
        $model_module =~ s#$directory/##;
        my $model_class = _module_to_class($model_module);
        #print $model_class,"\n";
        next unless $model_class->isa('Genome::Model');
        my ($model_subclass) = $model_class =~ m#::([\w\d]+)$#;
        push @model_subclasses, $model_subclass;
    }

    unless ( @model_subclasses ) {
        $self->error_message("No model type_names found in directory ($model_directory)");
        return;
    }

    return @model_subclasses;
}

sub get_model_type_names {
    my $self = shift;

    my @subclasses = $self->get_model_subclasses
        or return;

    return map { _camel_case_to_string($_, ' ') } @subclasses;
}

sub get_report_classes_for_type_name {
    my ($self, $type_name) = @_;

    unless ( $type_name ) {
        # die or err?
        die "No model sub type given\n"; 
        return;
    }

    # return if no reports dir
    my $directory = $self->get_inc_directory_for_class(__PACKAGE__);
    my $model_subclass = _string_to_camel_case($type_name);
    my $report_directory = "$directory/Genome/Model/$model_subclass/Report";
    #print $report_directory."\n";
    unless ( -d $report_directory ) {
        # "No report directory for model type_name ($type_name)"
        return;
    }

    my @report_classes;
    for my $report_module ( glob("$report_directory/*pm") ) {
        $report_module =~ s#$directory/##;
        my $report_class = _module_to_class($report_module);
        next unless $report_class->isa('Genome::Report::Generator');
        push @report_classes, $report_class;
    }

    return @report_classes;
}

sub get_report_subclasses_for_type_name {
    my ($self, $type_name) = @_;

    my @classes = $self->get_report_classes_for_type_name($type_name)
        or return;

    return map { $_ =~ m#::([\w\d]+)$# } @classes;
}

sub get_report_names_for_type_name {
    my ($self, $type_name) = @_;

    my @subclasses = $self->get_report_subclasses_for_type_name($type_name)
        or return;

    return map { _camel_case_to_string($_, ' ') } @subclasses;
}

#< Converter Methods >#
sub _string_to_camel_case {
    return join('', map { ucfirst } split(/[\s_]+/, $_[0]));
}

sub _camel_case_to_string {
    my $camel_case = shift;
    my $join = ( @_ )
    ? $_[0]
    : ' '; 
    my @words = $camel_case =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/g;
    return join($join, map { lc } @words);
}

sub _class_to_module {
    my $module = shift;
    $module =~ s/::/\//g;
    $module .= '.pm';
    return $module;
}

sub _module_to_class {
    my $module = shift;
    $module =~ s#\.pm##;
    $module =~ s#/#::#g;
    return $module;
}

1;

#$HeadURL$
#$Id$
