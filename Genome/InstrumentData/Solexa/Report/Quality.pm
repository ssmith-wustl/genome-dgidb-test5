package Genome::InstrumentData::Solexa::Report::Quality;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Solexa::Report::Quality {
    is => 'Genome::InstrumentData::Report',
    has => [
            name => {
                default_value =>'Quality',
            },
            description => {
                calculate_from => [qw/ instrument_data /],
                calculate => q|
                    return sprintf(
                        'Instrument Data Quality for (Run <%s> Lane <%s> ID<%s>)',
                        $instrument_data->run_name,
                        $instrument_data->subset_name,
                        $instrument_data->id
                    );
                |,
            },
        ],
};

sub _add_to_report_xml {
    my $self = shift;

    unless ($self->_generate_quality_stats) {
        $self->error_message('Failed to generate quality report data!');
        return;
    }
    return 1;
}

sub _generate_quality_stats {
    my $self = shift;

    my @fastq_suffix = qw/fastq fq txt/;
    my @fastq_filenames = @{$self->instrument_data->resolve_fastq_filenames};
    my $tmp_directory = File::Temp::tempdir( CLEANUP => 1 );

    my %stats_files;
    for my $fastq_filename (@fastq_filenames) {
        my ($basename,$dirname,$suffix) = File::Basename::fileparse($fastq_filename,@fastq_suffix);
        $basename =~ s/\.$//;
        my $stats_file = $tmp_directory .'/'. $basename .'.stats';
        my $quality_stats = Genome::Model::Tools::Fastx::QualityStats->create(
            fastq_file => $fastq_filename,
            stats_file => $stats_file,
        );
        unless ($quality_stats->execute) {
            $self->error_message('Failed to generate quality stats file for: '. $fastq_filename);
            die($self->error_message);
        }
        $stats_files{$basename} = $stats_file;
    }
    my @headers;
    my @rows;
    my $quality_stats_node = $self->_xml->createElement('quality-stats')
        or return;
    $self->_datasets_node->addChild($quality_stats_node)
        or return;
    my %params = (
        title => 'Instrument Data Quality Summary',
        'display-type' => 'candlestick',
        'x-axis-title' => 'Cycle/Column',
        'y-axis-title' => 'Quality',
    );
    for my $attr (keys %params) {
        $quality_stats_node->addChild( $self->_xml->createAttribute($attr, $params{$attr}) )
            or return;
    }
    for my $read_set (sort keys %stats_files) {
        my $read_set_node = $self->_xml->createElement('read-set')
            or return;
        $read_set_node->addChild( $self->_xml->createAttribute('read-set-name', $read_set) )
            or return;
        $quality_stats_node->addChild($read_set_node)
            or return;
        my $stats_filename = $stats_files{$read_set};
        my $parser = Genome::Utility::IO::SeparatedValueReader->create(
            input => $stats_filename,
            separator => "\t",
        );
        unless ($parser) {
            $self->error_message('Failed to create tab delimited parser for file '. $stats_filename);
            die($self->error_message);
        }
        unless (@headers) {
            @headers = @{$parser->headers};
        }
        while (my $stats = $parser->next) {
            my $cycle_node = $read_set_node->addChild( $self->_xml->createElement('cycle') );
            for my $header (@headers) {
                my $header_field = $header;
                $header_field =~ s/\_/-/g;
                my $element = $cycle_node->addChild( $self->_xml->createElement($header_field) )
                    or return;
                $element->appendTextNode($stats->{$header});
            }
        }
        $parser->input->close;
    }
    return 1;
}

1;
