package Genome::InstrumentData::Command::AlignmentResult::Merged::Merger::Picard;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::AlignmentResult::Merged::Merger::Picard {
    is => 'Genome::InstrumentData::Command::AlignmentResult::Merged::Merger',
    has_optional => [
        max_jvm_heap_size => {
            is => 'Number',
            doc => 'Size (in GB) of the JVM heap for Picard',
            is_constant => 1,
        },
    ],
};

# Need to be able to override this somehow in low memory environments.
# Ideally we would centralize the ability to determine a memory limit based on
# job dispatcher or hardware.
sub default_max_jvm_heap_size { 12 }

sub execute {
    my $self = shift;

    $self->max_jvm_heap_size($self->default_max_jvm_heap_size) unless $self->max_jvm_heap_size;

    my $merge_cmd = Genome::Model::Tools::Sam::Merge->create(
        files_to_merge => [$self->input_bams],
        merged_file => $self->output_path,
        is_sorted => 1,
        bam_index => 0,
        merger_name => 'picard',
        merger_version => $self->version,
        merger_params  => $self->parameters,
        use_version => $self->samtools_version,
        max_jvm_heap_size => $self->max_jvm_heap_size,
    );

    if (Genome::DataSource::GMSchema->has_default_handle) {
        $self->status_message("Disconnecting GMSchema default handle.");
        Genome::DataSource::GMSchema->disconnect_default_dbh();
    }

    my $merge_rv = $merge_cmd->execute();

    if ( not $merge_rv )  {
        $self->error_message("Error merging: ".join("\n", $self->input_bams));
        $self->error_message("Output target: " . $self->output_path);
        $self->error_message("Using software: picard");
        $self->error_message("Version: ". $self->version);
        $self->error_message("You may want to check permissions on the files you are trying to merge.");
        return;
    }

    return 1;
}

1;
