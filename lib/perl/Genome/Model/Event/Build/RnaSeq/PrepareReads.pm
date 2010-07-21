package Genome::Model::Event::Build::RnaSeq::PrepareReads;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::RnaSeq::PrepareReads {
    is => ['Genome::Model::Event'],
    has => [
    ],
};

sub execute {
    my $self = shift;
    unless (-d $self->build_directory) {
        $self->create_directory($self->build_directory);
        $self->status_message("Created build directory: ".$self->build_directory);
    } else {
        $self->status_message("Build directory exists: ".$self->build_directory);
    }
    my $build_fastq_directory = $self->build->accumulated_fastq_directory;
    unless (-d $build_fastq_directory) {
        Genome::Utility::FileSystem->create_directory($build_fastq_directory);
    }
    my $fastq_directory = $self->fastq_directory;
    unless (-d $fastq_directory) {
        Genome::Utility::FileSystem->create_directory($fastq_directory);
    }
    unless (Genome::InstrumentData::Command::Dump->execute(
        instrument_data_id => $self->instrument_data_id,
        directory => $fastq_directory,
    )) {
        $self->error_message('Failed to dump fastq file for '. $self->instrument_data_id .' to directory '. $fastq_directory);
        return;
    }
    return 1;
}

sub fastq_directory {
    my $self = shift;
    return $self->build->accumulated_fastq_directory .'/'. $self->instrument_data_id;
}


1;
