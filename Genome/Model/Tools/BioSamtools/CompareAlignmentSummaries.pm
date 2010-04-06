package Genome::Model::Tools::BioSamtools::CompareAlignmentSummaries;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::CompareAlignmentSummaries {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        input_files => {
            is => 'Text',
            doc => 'A list of input alignment summaries'
        },
        output_file => {
            is => 'Text',
            doc => 'A file path to store tab delimited output',
        },
        libraries => {
            is_optional => 1,
        }
    ],
};

sub execute {
    my $self = shift;

    my @data;
    my @headers;
    my $i = 0;
    my @libraries;
    if ($self->libraries) {
        @libraries = @{$self->libraries};
    }
    for my $input_file (@{$self->input_files}) {
        my $library;
        if ($self->libraries) {
            $library = $libraries[$i++];
        }
        my $reader = Genome::Utility::IO::SeparatedValueReader->create(
            separator => "\t",
            input => $input_file,
        );

        unless ($reader) {
            $self->error_message("Can't create SeparatedValueReader for input file $input_file");
            return;
        }
        while (my $data = $reader->next) {
            if ($library) {
                $data->{library} = $library;
            }
            push @data, $data;
            unless (@headers) {
                @headers = keys %{$data};
            }
        }
        $reader->input->close;
    }
    my $writer = Genome::Utility::IO::SeparatedValueWriter->create(
        separator => "\t",
        headers => \@headers,
        output => $self->output_file,
    );
    for my $data (@data) {
        $writer->write_one($data);
    }
    $writer->output->close;
    return 1;
}

1;
