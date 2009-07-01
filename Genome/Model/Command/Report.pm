package Genome::Model::Command::Report;

use strict;
use warnings;

use Genome;

require Carp;

class Genome::Model::Command::Report {
    is => 'Command',
    has => [ 
    # report
    report_name => { 
        is => 'Text', 
        doc => 'Report name',
    },
    report => {
        is => 'Genome::Report',
        calculate_from => [qw/ report_name build /],
        calculate => q|
            return $build->get_report($report_name);
        |,
        doc => 'The report from the build with report name',
    },
    # build and derivatives
    model => { 
        is => 'Genome::Model', 
        via => 'build',
        to => 'model',
    },
    build => { 
        is => 'Genome::Model::Build', 
        id_by => 'build_id',
        doc => 'Build',
    },
    build_id => {
        doc => 'Build id',
    },
    ],
};

#< Helps >#
sub help_brief {
    return "Operate on a build's reports"
}

sub sub_command_sort_position { 12 }

#< Command >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->report_name ) {
        $self->error_message("Report name is required to create");
        $self->delete;
        return;
    }
    
    $self->_validate_build_id
        or return;

    return $self;
}

#< Report >#
sub report {
    my $self = shift;

    unless ( $self->{_report} ) { 
        $self->{_report} = $self->build->get_report($self->report_name);
    }

    return $self->{_report};
}

#< Validations >#
sub _validate_build_id {
    my $self = shift;

    unless ( $self->build_id ) {
        $self->error_message("No build id given");
        return;
    }
    
    unless ( $self->build ) {
        $self->error_message("Can't get build for id: ". $self->build_id);
        return;
    }

    return 1;
}

sub _validate_report_name_for_build {
    my ($self, $build, $report_name) = @_;

    unless ( $build ) {
        $self->error_message("No build given to validate report name");
        return;
    }

    unless ( $report_name ) {
        $self->error_message("No report name given to validate report name");
        return;
    }
    
    my $type_name = $build->model->type_name;
    my @report_names = Genome::Model::Report::get_report_names_for_type_name($type_name);

    unless ( @report_names ) {
        $self->error_message('No report names for model type name: '.$build->model->type_name);
        return;
    }

    unless ( grep { $report_name eq $_ } @report_names ) {
        $self->error_message("Report name ($report_name) was not found for model type name ($type_name): ". join(', ', @report_names));
        return;
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
