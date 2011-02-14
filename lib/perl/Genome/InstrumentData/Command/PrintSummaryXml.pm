package Genome::InstrumentData::Command::PrintSummaryXml;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::PrintSummaryXml {
    is => 'Genome::InstrumentData::Command',
    has => [
        output_file => {
            is => 'Text',
            doc => 'The output xml file to write to',
        },
    ],
};

sub execute {
    my $self = shift;

    my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
    unless ($output_fh) {
        die('Failed to open output file for writing '. $self->output_file);
    }
    my $instrument_data = $self->instrument_data;
    my $xml_content = $instrument_data->summary_xml_content;
    unless ($xml_content) { return; }
    print $output_fh $xml_content ."\n";
    $output_fh->close;
    return 1;
}
