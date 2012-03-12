package Genome::Model::Tools::Rna::ModelGroupRnaSeqMetrics;

use strict;
use warnings;

use Genome;
use Statistics::Descriptive;

class Genome::Model::Tools::Rna::ModelGroupRnaSeqMetrics {
    is => 'Genome::Command::Base',
    has => [
        model_group => {
            is => 'Genome::ModelGroup',
            shell_args_position => 1,
            doc => 'Model group of RNAseq models to generate expression matrix.',
        },
        metrics_tsv_file => {
            doc => '',
            default_value => 'RnaSeqMetrics.tsv',
        },
    ],
    has_optional => [
        normalized_transcript_coverage_file => {
            doc => '',
            default_value => 'NormalizedTranscriptCoverage.tsv',
        },
    ],

};

sub help_synopsis {
    return <<"EOS"
    gmt rna model-group-rna-seq-metrics --model-group 2
EOS
}

sub help_brief {
    return "Accumulate RNAseq metrics for model group.";
}

sub help_detail {
    return <<EOS
SOMETHING ELSE.
EOS
}

sub execute {
    my $self = shift;
    my @models = $self->model_group->models;
    my @non_rna_models = grep { !$_->isa('Genome::Model::RnaSeq') } @models;
    if (@non_rna_models) {
        die('Found a non-RNAseq model: '. Data::Dumper::Dumper(@non_rna_models));
    }
    my @builds;
    my $annotation_build;
    my $reference_build;
    my %model_metrics;
    my @metric_headers = qw/LABEL TOTAL_READS TOTAL_READS_MAPPED TOTAL_READS_UNMAPPED PCT_READS_MAPPED/;
    my @model_metric_keys;
    for my $model (@models) {
        if ( defined($model_metrics{$model->name}) ) {
            die('Multiple models with name: '. $model->name);
        }
        my $build = $model->last_succeeded_build;
        unless ($build) {
            $build = $model->latest_build;
            unless ($build) {
                die('Failed to find build for model: '. $model->id);
            }
        }
        push @builds, $build;
        my $model_reference_sequence_build = $model->reference_sequence_build;
        if ($reference_build) {
            unless ($reference_build->id eq $model_reference_sequence_build->id) {
                $self->error_message('Mis-match reference sequence builds!');
                die($self->error_message);
            }
        } else {
            $reference_build = $model_reference_sequence_build;
        }
        my $model_annotation_build = $model->annotation_build;
        if ($annotation_build) {
            unless ($annotation_build->id eq $model_annotation_build->id) {
                $self->error_message('Mis-match annotation builds!');
                die($self->error_message);
            }
        } else {
            $annotation_build = $model_annotation_build;
        }
        my $metrics_directory = $build->data_directory .'/metrics';
        unless (-d $metrics_directory) {
            $self->error_message('Missing metrics directory: '. $metrics_directory);
            die($self->error_message);
        }
        my $metrics_file = $metrics_directory .'/PicardRnaSeqMetrics.txt';
        unless (-e $metrics_file) {
            $self->error_message('Missing Picard RNAseq metrics file: '. $metrics_file);
            die($self->error_message);
        }
        my $metrics = Genome::Model::Tools::Picard::CollectRnaSeqMetrics->parse_file_into_metrics_hashref($metrics_file);
        unless ($metrics) {
            die('Failed to parse metrics file: '. $metrics_file);
        }
        if ( !@model_metric_keys ) {
            @model_metric_keys = sort keys %{$metrics};
            push @metric_headers, @model_metric_keys;
        } else {
            #TODO: Check that all metrics files have the same headers...
        }
        $model_metrics{$model->name}{metrics} = $metrics;
        my $histo = Genome::Model::Tools::Picard::CollectRnaSeqMetrics->parse_metrics_file_into_histogram_hashref($metrics_file);
        # This is only available in picard v1.52 or greater
        if ($histo) {
            $model_metrics{$model->name}{histogram} = $histo;
        }
    }

    my $metrics_writer = Genome::Utility::IO::SeparatedValueWriter->create(
        output => $self->metrics_tsv_file,
        separator => "\t",
        headers => \@metric_headers,
    );

    my %transcript_coverage;
    for my $build (@builds) {
        my $name = $build->model->name;
        my $metrics = $model_metrics{$name}{'metrics'};

        my $tophat_stats =  $build->data_directory .'/alignments/alignment_stats.txt';
        my $tophat_fh = Genome::Sys->open_file_for_reading($tophat_stats);
        my %tophat_metrics;
        while (my $line = $tophat_fh->getline) {
            if ($line =~ /^##(.+):\s+(\d+)$/) {
                my $key = $1;
                my $value = $2;
                $key =~ s/ /_/g;
                $tophat_metrics{uc($key)} = $value;
            }
        }
        unless (defined($tophat_metrics{'TOTAL_READS'})) {
            die('Metrics not parsed correctly: '. Data::Dumper::Dumper(%tophat_metrics));
        }
        my %summary = (
            LABEL => $name,
            TOTAL_READS => $tophat_metrics{'TOTAL_READS'},
            TOTAL_READS_MAPPED => $tophat_metrics{'TOTAL_READS_MAPPED'},
            TOTAL_READS_UNMAPPED => ($tophat_metrics{'TOTAL_READS'} - $tophat_metrics{'TOTAL_READS_MAPPED'}),
            PCT_READS_MAPPED => ($tophat_metrics{'TOTAL_READS_MAPPED'} / $tophat_metrics{'TOTAL_READS'}),
        );
        for my $header (@metric_headers) {
            # This assumes all other values have been set
            if ( !defined($summary{$header}) ) {
                $summary{$header} = $metrics->{$header};
            }
        }
        $metrics_writer->write_one(\%summary);
        if (defined($model_metrics{$name}{'histogram'}) ) {
            my $histo = $model_metrics{$name}{'histogram'};
            for my $position (keys %{$histo}) {
                $transcript_coverage{$position}{$name} = $histo->{$position}{normalized_coverage};
            }
        }
    }

    if ($self->normalized_transcript_coverage_file) {
        my @models = sort keys %model_metrics;
        my @coverage_headers = ('POSITION',@models);
        my $coverage_writer = Genome::Utility::IO::SeparatedValueWriter->create(
            output => $self->normalized_transcript_coverage_file,
            separator => "\t",
            headers => \@coverage_headers,
        );
        for my $position (sort {$a <=> $b} keys %transcript_coverage) {
            my %data = (
                POSITION => $position,
            );
            for my $label (@models) {
                $data{$label} = $transcript_coverage{$position}{$label};
            }
        $coverage_writer->write_one(\%data);
        }
    }
    return 1;
}
