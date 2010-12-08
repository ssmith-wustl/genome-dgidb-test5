package Genome::Model::MetagenomicComposition16s::Command::RunStatus; 

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require Carp;

class Genome::Model::MetagenomicComposition16s::Command::RunStatus {
    is => 'Genome::Report::GeneratorCommand',
    has => [
        run_name => {
            is_many => 0,
            shell_args_position => 1,
            doc => 'Run name.',
        },
        region_number => {
            shell_args_position => 2,
            doc => 'Region Number.',
        },
    ],
};

sub help_brief { 
    return 'Get the status for models for a 454 run';
}

sub help_detail {
    return help_brief();
}

sub execute {
    my $self = shift;
    
    my @instrument_data = Genome::InstrumentData::454->get(
        run_name => $self->run_name,
        region_number => $self->region_number,
    );

    my @headers = (qw/ sample-name instrument-data-id model-id build-id status oriented-fastas /);
    my @rows;
    for my $instrument_data ( @instrument_data ) {
        my @row;
        push @rows, \@row;
        my $library = $instrument_data->library;
        my $sample = $library->sample;
        push @row, $sample->name;
        push @row, $instrument_data->id;
        my @models = Genome::Model::MetagenomicComposition16s->get(subject_id => $sample->id);
        if ( not @models ) {
            #push @row, (qw/ NO_MODEL NO_BUILD NO_STATUS NO_FASTAS /);
            next;
        }
        push @row, $models[0]->name;
        my $build = $models[0]->last_succeeded_build;
        if ( not $build ) {
            #push @row, (qw/ NO_BUILD NO_STATUS NO_FASTAS /);
            next;
        }
        push @row, map { $build->$_ } (qw/ id status oriented_fasta_files /);
    }

    my $report = $self->_generate_report_and_execute_functions(
        name => 'Work Order Status',
        description => 'Run Status for '.$self->run_name.' '.$self->region_number,
        row_name => 'instrument-data',
        headers => \@headers,
        rows => \@rows,
    ) or return;

    #my %stats;
    #print STDERR Dumper(\%stats);

    return $report;
}

1;

