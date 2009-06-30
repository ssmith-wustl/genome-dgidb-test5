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

    # Assembly Stats
    my $stats_generator = Genome::Model::AmpliconAssembly::Report::AssemblyStats->create(
        build_id => $self->build->id,
    );
    unless ( $stats_generator ) {
        $self->error_message(
            sprintf(
                'Could not create assembly stats report generator (MODEL <Name:%s Id:%s> BUILD <Id:%s>)', 
                $self->model->name,
                $self->model->id,
                $self->build->id,
            )
        );
        return;
    }
    my $stats_report = $stats_generator->generate_report;
    unless ( $stats_report ) {
        $self->error_message(
            sprintf(
                'Could not generate assembly stats report (MODEL <Name:%s Id:%s> BUILD <Id:%s>)', 
                $self->model->name,
                $self->model->id,
                $self->build->id,
            )
        );
        return;
    }

    unless ( $self->build->add_report($stats_report) ) {
        $self->error_message(
            sprintf(
                'Could not save assembly stats report (MODEL <Name:%s Id:%s> BUILD <Id:%s>)', 
                $self->model->name,
                $self->model->id,
                $self->build->id,
            )
        );
    }

    #print $self->build->data_directory."\n"; <STDIN>;
    
    return 1;
}

1;

#$HeadURL$
#$Id$
