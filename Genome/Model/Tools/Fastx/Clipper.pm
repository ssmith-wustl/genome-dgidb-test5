package Genome::Model::Tools::Fastx::Clipper;

use strict;
use warnings;

use Genome;
use Genome::Utility::FileSystem;
use File::Basename;

class Genome::Model::Tools::Fastx::Clipper {
    is => ['Genome::Model::Tools::Fastx'],
    has_constant => {
        fastx_tool => { value => 'fastx_clipper' },
    },
    has_input => [
        input => {
            is => 'Text',
            doc => 'The input FASTQ/A file to collapse.(This works on fastq but I get errors about the quality string)',
        },
        output => {
            is => 'Text',
            doc => 'The output FASTQ/A file containing collapsed sequence.',
            is_optional => 1,
        },
        params => {
            is => 'Text',
        }
    ],
};

sub execute {
    my $self = shift;
    unless (Genome::Utility::FileSystem->validate_file_for_reading($self->input)) {
        $self->error_message('Failed to validate fastq file for read access '. $self->input .":  $!");
        die($self->error_message);
    }
    my @suffix = qw/fq fa fastq fasta fna txt/;
    my ($basename,$dirname,$suffix) = File::Basename::fileparse($self->input,@suffix);
    $basename =~ s/\.$//;
    unless ($self->output) {
        $self->output_file($dirname .'/'. $basename .'_clipped.'. $suffix);
    }
    unless (Genome::Utility::FileSystem->validate_file_for_writing($self->output)) {
        $self->error_message('Failed to validate output file for write access '. $self->output .":  $!");
        die($self->error_message);
    }
    my $cmd = $self->fastx_tool_path .' '. $self->params .' -i '. $self->input .' -o '. $self->output;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->input],
        output_files => [$self->output],
    );
    return 1;
}

1;
