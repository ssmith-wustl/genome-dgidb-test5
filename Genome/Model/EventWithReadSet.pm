package Genome::Model::EventWithReadSet;

use strict;
use warnings;

use above "Genome";

class Genome::Model::EventWithReadSet {
    is => 'Genome::Model::Event',
    is_abstract => 1,
    has => [
        read_set            => { is => 'Genome::RunChunk', id_by => 'run_id', is_optional => 0, constraint_name => 'event_run' },
        read_set_id         => { via => 'read_set', to => 'seq_id' }, # not really the fk currently (run_id), see below...

        run_name            => { via => 'read_set' },
        run_short_name      => { via => 'read_set', to => 'short_name' },
        run_subset_name     => { via => 'read_set', to => 'subset_name' },
        read_set_directory  => {
                                calculate_from => ['model','read_set'],
                                calculate => q|
                                    return sprintf('%s/runs/%s/%s',$model->data_directory,
                                                                   $read_set->sequencing_platform,
                                                                   $read_set->name);
                                |,
                            },
        alignment_links_directory => { via => 'model'},
        read_set_alignment_directory  => {
                                          calculate_from => ['alignment_links_directory','read_set'],
                                          calculate => q|
                                              return sprintf('%s/%s',$alignment_links_directory,$read_set->seq_id);
                                          |,
                            },
        library_name        => { via => 'read_set' },
        sample_name         => { via => 'read_set' },

        # deprecated
        resolve_run_directory => {
                                  calculate_from => ['read_set_directory'],
                                  calculate => q|
                                      return $read_set_directory,
                                  |,
                                  is_deprecated => 1,
                              },
        run_id              => { is => 'NUMBER', len => 11, is_optional => 0, doc => 'the genome_model_run on which to operate', is_deprecated => 1 }, # don't use
        run                 => { is => 'Genome::RunChunk', id_by => 'run_id', is_deprecated => 1 }, # use read_set
    ],
    sub_classification_method_name => '_get_sub_command_class_name',
};

sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep {
            not (
                $_->class_name eq __PACKAGE__
                and $_->property_name !~ /(model_id|run_id)/
            )
        } shift->SUPER::_shell_args_property_meta(@_);
}

sub invalid {
    my ($self) = shift;

    my @tags = $self->SUPER::invalid(@_);
    unless (Genome::Model->get($self->model_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['model_id'],
                                            desc => "There is no model with id ". $self->model_id,
                                        );
    }

    unless (Genome::RunChunk->get(id => $self->run_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['run_id'],
                                            desc => "There is no genome run with id ". $self->run_id,
                                        );
    }
    return @tags;
}


# maq map file for all this lane's alignments
sub unique_alignment_file_for_lane {
    my($self) = @_;

    return $self->resolve_run_directory . '/unique_alignments_lane_' . $self->run_subset_name . '.map';
}

sub duplicate_alignment_file_for_lane {
    my($self) = @_;

    return $self->resolve_run_directory . '/duplicate_alignments_lane_' . $self->run_subset_name . '.map';
}


# fastq file for all the reads in this lane
sub fastq_file_for_lane {
    my($self) = @_;

    return sprintf("%s/s_%s_sequence.fastq", $self->resolve_run_directory, $self->run_subset_name);
}

# a file containing sequence\tread_name\tquality sorted by sequence
sub sorted_fastq_file_for_lane {
    my($self) = @_;

    return sprintf("%s/s_%s_sequence.sorted.fastq", $self->resolve_run_directory, $self->run_subset_name);
}

sub Xoriginal_sorted_unique_fastq_file_for_lane {
    my($self) = @_;

    return sprintf("%s/%s_sequence.unique.sorted.fastq", $self->run->full_path, $self->run_subset_name);
}

sub Xsorted_unique_fastq_file_for_lane {
    my($self) = @_;

    return sprintf("%s/s_%s_sequence.unique.sorted.fastq", $self->resolve_run_directory, $self->run_subset_name);
}

sub Xoriginal_sorted_duplicate_fastq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/%s_sequence.duplicate.sorted.fastq", $self->run->full_path, $self->run_subset_name);

}

sub Xsorted_duplicate_fastq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.duplicate.sorted.fastq", $self->resolve_run_directory, $self->run_subset_name);

}

# The maq bfq file that goes with that lane's fastq file
sub unique_bfq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unique.bfq", $self->resolve_run_directory, $self->run_subset_name);
}

sub duplicate_bfq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.duplicate.bfq", $self->resolve_run_directory, $self->run_subset_name);
}

sub unaligned_unique_reads_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unaligned.unique", $self->resolve_run_directory, $self->run_subset_name);
}

sub unaligned_distinct_fastq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unaligned.distinct.fastq", $self->resolve_run_directory, $self->run_subset_name);
}

sub unaligned_duplicate_reads_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unaligned.duplicate", $self->resolve_run_directory, $self->run_subset_name);
}

sub unaligned_redundant_fastq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unaligned.redundant.fastq", $self->resolve_run_directory, $self->run_subset_name);
}

sub aligner_unique_output_file_for_lane {
    return $_[0]->unique_alignment_file_for_lane . '.aligner_output';
}

sub aligner_duplicate_output_file_for_lane {
    return $_[0]->duplicate_alignment_file_for_lane . '.aligner_output';
}

sub alignment_submaps_dir_for_lane {
    my $self = shift;
    return sprintf("%s/alignments_lane_%s.submaps", $self->resolve_run_directory, $self->run_subset_name)
}


1;

