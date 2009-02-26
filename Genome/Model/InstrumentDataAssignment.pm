package Genome::Model::InstrumentDataAssignment;

use strict;
use warnings;

use Genome;
class Genome::Model::InstrumentDataAssignment {
    table_name => 'MODEL_INSTRUMENT_DATA_ASSGNMNT',
    id_by => [
        model => { 
            is => 'Genome::Model',
            id_by => 'model_id',
        },
        instrument_data => { 
            is => 'Genome::InstrumentData',
            id_by => 'instrument_data_id',
        },
    ],
    has => [
        first_build_id => { is => 'NUMBER', len => 10, is_optional => 1 },

        #< Attributes from the instrument data >#
        run_name => { via => 'instrument_data'},

        #< Left over from Genome::Model::ReadSet >#
        # PICK ONE AND FIX EVERYTHING THAT USES THIS
        subset_name         => { via => 'instrument_data'},
        run_subset_name     => { via => 'instrument_data', to => 'subset_name'},
        # PICK ONE AND FIX EVERYTHING THAT USES THIS
        short_name          => { via => 'instrument_data' },
        run_short_name      => { via => 'instrument_data', to => 'short_name' },
        library_name        => { via => 'instrument_data' },
        sample_name         => { via => 'instrument_data' },
        sequencing_platform => { via => 'instrument_data' },
        full_path           => { via => 'instrument_data' },
        full_name           => { via => 'instrument_data' },
        _calculate_total_read_count => { via => 'instrument_data' },
        unique_reads_across_library     => { via => 'instrument_data' },
        duplicate_reads_across_library  => { via => 'instrument_data' },
        median_insert_size => {via => 'instrument_data'},
        sd_above_insert_size => {via => 'instrument_data'},
        is_paired_end => {via => 'instrument_data' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

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

    unless (Genome::InstrumentData->get($self->instrument_data_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['instrument_data_id'],
                                            desc => "There is no instrument data with id ". $self->instrument_data_id,
                                        );
    }
    return @tags;
}

*read_set_alignment_directory = \&alignment_directory;

sub alignment_directory {
    my $self = shift;
    my $model = $self->model;
    my $instrument_data = $self->instrument_data;
    return $instrument_data->alignment_directory_for_aligner_and_refseq(
                                                                        $model->read_aligner_name,
                                                                        $model->reference_sequence_name,
                                                                    );
}

*read_set_alignment_files_for_refseq = \&alignment_files_for_refseq;

sub alignment_files_for_refseq {
    # this returns the above, or will return the old-style split maps
    my $self = shift;
    my $ref_seq_id = shift;
    unless (defined($ref_seq_id)) {
        $self->error_message('No ref_seq_id passed to method alignment_files_for_refseq');
        return;
    }

    my $alignment_dir = $self->alignment_directory;
    unless (-d $alignment_dir) {
        $self->error_message("The read_set_alignment_directory '$alignment_dir' does not exist.");
        return;
    }

    # Look for files in the new format: $refseqid.map.$eventid
    my @files = grep { $_ and -e $_ } (
        glob($alignment_dir . "/$ref_seq_id.map.*") #bkward compat
    );
    return @files if (@files);

    # Now try the old format: $refseqid_{unique,duplicate}.map.$eventid
    my $glob_pattern = sprintf('%s/%s_*.map.*', $alignment_dir, $ref_seq_id);
    @files = grep { $_ and -e $_ } (
        glob($glob_pattern)
    );
    return @files;
}

sub alignment_file_paths {
    my $self=shift;
    return unless -d $self->alignment_directory;
   return grep { -e $_ && $_ !~ /aligner_output/ } glob($self->alignment_directory .'/*'. '*.map*');
}

sub aligner_output_file_paths {
    my $self=shift;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } glob($self->alignment_directory .'/*'. '.map.aligner_output.*');
}

sub poorly_aligned_reads_list_paths {
    my $self=shift;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } grep { $_ !~ /\.fastq$/ } glob($self->alignment_directory .'/*'.
                                                         $self->subset_name .'_sequence.unaligned.*');
}

sub poorly_aligned_reads_fastq_paths  {
    my $self=shift;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } glob($self->alignment_directory .'/*'.
                               $self->subset_name .'_sequence.unaligned.*.fastq');
}

sub contaminants_file_path {
    my $self=shift;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } glob($self->alignment_directory .'/adaptor_sequence_file');
}

sub get_alignment_statistics {
    my $self = shift;
    my ($aligner_output_file) = $self->aligner_output_file_paths;
    unless ($aligner_output_file && -s $aligner_output_file) {
        $self->error_message("No aligner output file '$aligner_output_file' found or zero size");
        return;
    }
    return Genome::InstrumentData::Command::Align::Maq->get_alignment_statistics($aligner_output_file);
}
sub read_length {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    unless ($instrument_data) {
        die('no instrument data for id '. $self->instrument_data_id .'  '. Data::Dumper::Dumper($self));
    }
    my $read_length = $instrument_data->read_length;
    if ($read_length <= 0) {
        die("Impossible value '$read_length' for read_length field for instrument data:". $self->id);
    }
    return $read_length;
}
sub yaml_string {
    my $self = shift;
    return YAML::Dump($self);
}

sub delete {
    my $self = shift;

    $self->warning_message('DELETING '. $self->class .': '. $self->id);
    return $self->SUPER::delete();
}

1;

#$HeadURL$
#$Id$
