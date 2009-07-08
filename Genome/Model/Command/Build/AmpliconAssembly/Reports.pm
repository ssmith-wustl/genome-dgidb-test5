package Genome::Model::Command::Build::AmpliconAssembly::Reports;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Command::Build::AmpliconAssembly::Reports {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    for my $report_type ('assembly stats', 'composition') {
        $self->_generate_and_save_report($report_type);
    }

    return 1;
}

sub _generate_and_save_report {
    my ($self, $type) = @_;

    my $class = 'Genome::Model::AmpliconAssembly::Report::'.Genome::Utility::Text::string_to_camel_case($type);
    my $generator = $class->create(
        build_id => $self->build->id,
    );
    unless ( $generator ) {
        $self->error_message(
            sprintf(
                'Could not create %s report generator (MODEL <Name:%s Id:%s> BUILD <Id:%s>)', 
                $type,
                $self->model->name,
                $self->model->id,
                $self->build->id,
            )
        );
        return;
    }
    my $report = $generator->generate_report;
    unless ( $report ) {
        $self->error_message(
            sprintf(
                'Could not generate %s report (MODEL <Name:%s Id:%s> BUILD <Id:%s>)', 
                $type,
                $self->model->name,
                $self->model->id,
                $self->build->id,
            )
        );
        return;
    }

    unless ( $self->build->add_report($report) ) {
        $self->error_message(
            sprintf(
                'Could not save %s report (MODEL <Name:%s Id:%s> BUILD <Id:%s>)', 
                $type,
                $self->model->name,
                $self->model->id,
                $self->build->id,
            )
        );
    }

    return $report;
}

1;

#$HeadURL$
#$Id$
