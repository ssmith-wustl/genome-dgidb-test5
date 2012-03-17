package Genome::Model::DeNovoAssembly::Command::Metrics;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::DeNovoAssembly::Command::Metrics {
    is => 'Command::V2',
    has => [
	    build => {
            is => 'Genome::Model::Build',
            shell_args_position => 1,
            doc => 'Build to trun metrics.',
        },
    ],
    has_optional => [
        save_to_db => {
            is => 'Boolean',
            doc => 'Save (or replace) the metrics for the build to the database.',
        },
    ],
};

sub help_brief {
    'Run metrics for a build, optionally saving to the db',
}

sub help_detail {
    return;
}

sub execute {
    my $self = shift;
    $self->status_message('De Novo metrics...');

    my $build = $self->build;
    if ( not $build ) {
        $self->error_message('Failed to get build to run metrics!');
        return;
    }

    my $metrics_class = $build->processing_profile->tools_base_class.'::Metrics';
    my $major_contig_length = ( $build->processing_profile->name =~ /PGA/ ? 300 : 500 );
    $self->status_message('Assembly directory: '.$build->data_directory);
    $self->status_message('Major contig length: '.$major_contig_length);
    my $metrics_tool = $metrics_class->create(
        assembly_directory => $build->data_directory,
        major_contig_length => $major_contig_length,
    );
    if ( not $metrics_tool ) {
        $self->error_message('Failed to create metrics tool: '.$metrics_class);
        return;
    }
    $metrics_tool->dump_status_messages(1);
    unless( $metrics_tool->execute ) {
        $self->error_message("Failed to execute stats");
        return;
    }

    my $metrics = $metrics_tool->_metrics;
    my $print = $self->_print_to_stdout($metrics);
    return if not $print;

    if ( $self->save_to_db ) {
        $self->status_message('Save to db...');
        my $save = $self->_update_db($build, $metrics);
        return if not $save;
        $self->status_message('Save to db...OK');
    }

    $self->status_message('Done');
    return 1;
}

sub _print_to_stdout {
    my ($self, $metrics) = @_;

    Carp::confess('No metrics to print!') if not $metrics;

    my $text = $metrics->to_text;
    if ( not $text ) {
        $self->error_message('Failed to transform metrics to text!');
        return;
    }
    print $text;

    return 1;
}

sub _update_db {
    my ($self, $build, $metrics) = @_;

    Carp::confess('No build to save metrics!') if not $build;
    Carp::confess('No metrics to save!') if not $metrics;

    my $metrics_obj = $metrics->metrics;
    if ( not $metrics ) {
        $self->error_message('Failed to get metrics!');
        return;
    }

    for my $metric ( $build->metrics ) {
        $metric->delete;
    }

    $metrics->set_metric('reads_attempted', $build->reads_attempted);
    $metrics->set_metric('reads_processed_success', $build->reads_processed_success);

    for my $name ( $build->metric_names ) {
        my $add = $build->add_metric(
            name => $name,
            value => $metrics_obj->$name,
        );
    }

    return 1;
}

1;

