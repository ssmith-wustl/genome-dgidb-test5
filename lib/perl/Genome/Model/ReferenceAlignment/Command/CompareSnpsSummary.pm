package Genome::Model::ReferenceAlignment::Command::CompareSnpsSummary;

use strict;
use warnings;
use Genome;
use Carp 'confess';

class Genome::Model::ReferenceAlignment::Command::CompareSnpsSummary {
    is => 'Genome::Command::Base',
    has => [
        build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            id_by => 'build_id',
            shell_args_position => 1,
        },
        build_id => {
            is => 'Number',
        },
    ],
};

sub summary_headers {
    return qw/
        instrument_data_id
        reference_match
        reference_was_heterozygous
        overall_concordance
    /;
}

sub qc_metrics {
    return qw/
        compare_snps_ref_match
        compare_snps_ref_was_het
        compare_snps_overall_concord
    /;
}

sub execute {
    my $self = shift;
    my @instrument_data = $self->build->instrument_data;
    confess 'Found no instrument data assigned to build!' unless @instrument_data;

    print join("\t", $self->summary_headers) . "\n"; 
    for my $instrument_data (@instrument_data) {
        my @info;
        push @info, $instrument_data->id;

        my $qc_build = $instrument_data->lane_qc_build;
        unless ($qc_build) {
            print join("\t", @info, "No lane qc build available") . "\n";
            next;
        }

        my @metrics = Genome::Model::Metric->get(
            build_id => $qc_build->id,
            name => [$self->qc_metrics],
        );
        unless (@metrics) {
            @metrics = $self->create_and_retrieve_qc_metrics($qc_build);
            unless (@metrics) {
                print join("\t", @info, "No qc metrics could be found or generated") . "\n";
                next;
            }
        }

        for my $metric_name ($self->qc_metrics) {
            my ($metric) = grep { $_->name eq $metric_name } @metrics;
            if ($metric) {
                push @info, $metric->value;
            }
            else {
                push @info, "No value";
            }
        }
        
        print join("\t", @info) . "\n";
    }

    return 1;
}

sub create_and_retrieve_qc_metrics {
    my ($self, $qc_build) = @_;

    my $rv = Genome::Model::ReferenceAlignment::Command::CreateMetrics::CompareSnps->execute(
        build_id => $qc_build->id,
    );
    return unless $rv;

    return Genome::Model::Metric->get(
        build_id => $qc_build->id,
        name => [$self->qc_metrics],
    );
}

1;

