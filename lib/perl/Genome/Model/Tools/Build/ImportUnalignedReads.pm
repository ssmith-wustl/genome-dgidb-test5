package Genome::Model::Tools::Build::ImportUnalignedReads;

use strict;
use warnings;
use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Build::ImportUnalignedReads {
    is => 'Command',
    has => [
    build_id => {
        type => 'String',
        is_optional => 0,
        doc => "Build id to gather unaligned reads from",
    },
    ]
};

sub execute {
    #process inputs
    my $self = shift;
    my $build_id = $self->build_id;

    #check for build and model in the system
    my $build = Genome::Model::Build->get($build_id);
    unless(defined($build)) {
        $self->error_message("Unable to find build $build_id.\n");
        return;
    }
    my $model = $build->model;
    unless(defined($model)) {
        $self->error_message("Somehow this build ($build_id) does not have a model.\n");
        return;
    }

    #gather details of the build and model
    my $model_id = $model->id;
    my $description = 'unaligned reads from build ' . $build_id;
    my $sample_name = $model->subject_name;
    my $import_source_name = "model_" . $model_id . "_build_" . $build_id;

    #gather details from the alignments
    my @alignments = $model->instrument_data_assignments;
    for my $alignment (@alignments) {
        my $library = $alignment->library_name;
        my $flow_cell = $alignment->short_name;
        my $subset_name = $alignment->subset_name;
        my $fastq_paths = join(",",$alignment->alignment_set->unaligned_reads_fastq_paths);
        
        #check to see if data is paired-end
        my $import_as_paired_end = 1;
        if (defined($alignment->filter_desc) || $alignment->is_paired_end eq 0) {
            $import_as_paired_end = 0;
        }

        #check to see if there are two files for paired-end import
        my $no_commas = grep(!/,/,$fastq_paths);
        if ($import_as_paired_end && $no_commas) {
            $self->error_message("Importing as paired-end, but with only 1 fastq file for build $build_id, flow_cell $flow_cell, lane $subset_name.");
            return;
        }
        
        #perform import
        my $import_command = Genome::InstrumentData::Command::Import::Fastq->create(
            library_name => $library,
            source_data_files => $fastq_paths,
            import_format => "fastq",
            sample_name => $sample_name,
            import_source_name => $import_source_name,
            is_paired_end => $import_as_paired_end,
            sequencing_platform => "solexa",
            subset_name => $subset_name,
            description => "unaligned reads from build $build_id, flow_cell $flow_cell, lane $subset_name",
        );
        $import_command->execute;
    }

    return 1;
}

sub help_brief {
    "import unaligned reads from a build into instrument-data"
}

sub help_detail {
    "This script queries a build to find the paths to the unaligned fastq files for each lane, and then imports them into the instrument-data system so that they might be available for future use."
}

1;
