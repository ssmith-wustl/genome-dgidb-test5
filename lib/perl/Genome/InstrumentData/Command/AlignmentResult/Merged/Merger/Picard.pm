package Genome::InstrumentData::Command::AlignmentResult::Merged::Merger::Picard;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::AlignmentResult::Merged::Merger::Picard {
    is => 'Genome::InstrumentData::Command::AlignmentResult::Merged::Merger',
    has_constant => [
        max_jvm_heap_size => {
            is => 'Number',
            doc => 'Size (in GB) of the JVM heap for Picard',
            value => 12,
        },
    ],
};

sub execute {
    my $self = shift;

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

    Genome::DataSource::GMSchema->disconnect_default_dbh if Genome::DataSource::GMSchema->has_default_dbh;

    my $merge_rv = $merge_cmd->execute();

    if ($merge_rv != 1)  {
        $self->error_message("Error merging: ".join("\n", @{ $self->input_bams }));
        $self->error_message("Output target: " . $self->output_path);
        $self->error_message("Using software: picard");
        $self->error_message("Version: ". $self->version);
        $self->error_message("You may want to check permissions on the files you are trying to merge.");
        return;
    }

    return 1;
}

1;
