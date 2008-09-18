package Genome::Model::ReadSet;

use strict;
use warnings;

use Genome;
class Genome::Model::ReadSet {
    table_name => 'GENOME_MODEL_READ_SET',
    id_by => [
        model               => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMRSET_GM_PK ' },
        read_set            => { is => 'Genome::RunChunk', id_by =>'read_set_id'},

    ],
    has => [    
        alignment_directory => { via => 'model'},
        run_name            => { via => 'read_set'},
        subset_name         => { via => 'read_set'},
        run_short_name      => { via => 'read_set', to => 'short_name' },
        library_name        => { via => 'read_set' },
        sample_name         => { via => 'read_set' },
        unique_reads_across_library     => { via => 'read_set' },
        duplicate_reads_across_library  => { via => 'read_set' },

 
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub read_set_alignment_directory {
    my $self = shift;

    return sprintf('%s/%s/%s_%s',
                       $self->alignment_directory,
                       $self->run_name,
                       $self->subset_name,
                       $self->read_set_id
                  );
}

sub new_read_set_alignment_directory {
    my $self=shift;
    return sprintf('%s/%s/%s/%s',
                       $self->alignment_directory,
                       $self->sample_name,
                       $self->run_name,
                       $self->subset_name,
                  );
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

    unless (Genome::RunChunk->get(id => $self->read_set_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['read_set_id'],
                                            desc => "There is no genome run with id ". $self->read_set_id,
                                        );
    }
    return @tags;
}

sub alignment_file_paths {
    my $self=shift;
    return unless -d $self->read_set_alignment_directory;;
    return grep { -e $_ } glob("${$self->read_set_alignment_directory}/*${$self->subset_name}.submaps/*.map");
}
sub aligner_output_file_paths {
    my $self=shift;
    return unless -d $self->read_set_alignment_directory;
    return grep { -e $_ } glob("${$self->read_set_alignment_directory}/*${$self->subset_name}.map.aligner_output");
}
sub poorly_aligned_reads_list_paths {
    my $self=shift;
    return unless -d $self->read_set_alignment_directory;;
    return grep { -e $_ } grep { $_ !~ /\.fastq$/ } glob("${$self->read_set_alignment_directory}/*${$self->subset_name}_sequence.unaligned.*");
}
sub poorly_aligned_reads_fastq_paths  {
    my $self=shift;
    return unless -d $self->read_set_alignment_directory;;
    return grep { -e $_ } glob("${$self->read_set_alignment_directory}/*${$self->subset_name}_sequence.unaligned.*.fastq");
}
sub contaminants_file_path {
    my $self=shift;
    return unless -d $self->read_set_alignment_directory;;
    return grep { -e $_ } glob("${$self->read_set_alignment_directory}/adaptor_sequence_file");
}
sub read_length {
    my $self=shift;
    if ($self->read_set->read_length <= 0) {
        die('Impossible value for read_length field. seq_id:'. $self->read_set->seq_id);
    }
    return $self->read_set->read_length;
}
sub _calculate_total_read_count {
    my $self=shift;
    if ($self->read_set->clusters <= 0) {
        die('Impossible value for clusters field. seq_id:'. $self->read_set->seq_id);
    }
    return $self->read_set->clusters;
}

sub read_set_alignment_files_for_refseq {
    # this returns the above, or will return the old-style split maps
    my $self = shift;
    my $ref_seq_id = shift;
    my $read_set = $self->read_set;
    my $alignment_dir = $self->read_set_alignment_directory;

    # Look for files in the new format: $refseqid.map.$eventid
    my @files = grep { $_ and -e $_ } (
        glob($self->read_set_alignment_directory . "/$ref_seq_id.map.*") #bkward compat
    );
    return @files if (@files);

    # Now try the old format: $refseqid_{unique,duplicate}.map.$eventid
    my $glob_pattern = sprintf('%s/%s_*.map.*', $alignment_dir, $ref_seq_id);
    @files = grep { $_ and -e $_ } (
        glob($glob_pattern)
    );
    return @files;
}





1;
