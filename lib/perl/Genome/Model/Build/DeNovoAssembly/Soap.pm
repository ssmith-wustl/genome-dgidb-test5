package Genome::Model::Build::DeNovoAssembly::Soap;

use strict;
use warnings;

use Genome;
use Data::Dumper 'Dumper';

class Genome::Model::Build::DeNovoAssembly::Soap {
    is => 'Genome::Model::Build::DeNovoAssembly',
};

#< Files >#
sub soap_output_dir_and_file_prefix {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix;
}

sub file_prefix {
    return $_[0]->model->subject_name.'_'.$_[0]->center_name;
}

sub assembler_forward_input_file_for_library_id {
    my ($self, $library_id) = @_;
    return $self->data_directory.'/'.$self->file_prefix.'.'.$library_id.'.forward.fastq';
}

sub assembler_reverse_input_file_for_library_id {
    my ($self, $library_id) = @_;
    return $self->data_directory.'/'.$self->file_prefix.'.'.$library_id.'.reverse.fastq';
}

sub assembler_fragment_input_file_for_library_id {
    my ($self, $library_id) = @_;
    return $self->data_directory.'/'.$self->file_prefix.'.'.$library_id.'.fragment.fastq';
}

sub read_processor_output_files_for_instrument_data {
    my ($self, $instrument_data) = @_;

    my $library_id = $instrument_data->library_id;
    $library_id = 'unknown' if not defined $library_id;
    if ( $instrument_data->is_paired_end ) {
        return ( 
            $self->assembler_forward_input_file_for_library_id($library_id),
            $self->assembler_reverse_input_file_for_library_id($library_id),
        );
    }
    else {
        return $self->ssembler_fragment_input_file_for_library_id($library_id);
    }
}

sub libraries_with_existing_assembler_input_files {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    if ( not @instrument_data ) {
        $self->error_message('No instrument data found for .'.$self->description);
        return;
    }

    my @libraries;
    for my $instrument_data ( @instrument_data ) {
        my $library_id = $instrument_data->library_id || 'unknown';
        next if grep { $library_id eq $_->{library_id} } @libraries;
        my $insert_size = $instrument_data->median_insert_size;
        my %files = $self->existing_assembler_input_files_for_library_id($library_id);
        next if not %files;
        my %library = (
            library_id => $library_id,
            insert_size => $insert_size,
        );
        $library{paired_fastq_files} = $files{paired_fastq_files} if exists $files{paired_fastq_files};
        $library{fragment_fastq_files} = $files{fragment_fastq_files} if exists $files{fragment_fastq_files};
        push @libraries, \%library;
    }

    return @libraries;
}

sub existing_assembler_input_files_for_library_id {
    my ($self, $library_id) = @_;

    if ( not defined $library_id ) {
        $self->error_message('No library id given to get existing assembler input files');
        return;
    }

    my %files;
    my $forward_fastq_file = $self->assembler_forward_input_file_for_library_id($library_id);
    my $reverse_fastq_file = $self->assembler_reverse_input_file_for_library_id($library_id);
    my $fragment_fastq_file = $self->assembler_fragment_input_file_for_library_id($library_id);

    if ( not -s $forward_fastq_file and not -s $reverse_fastq_file and not -s $fragment_fastq_file ) {
        $self->error_message("No assembler input fastqs exist for library ($library_id).");
        return;
    }

    if ( -s $forward_fastq_file and -s $reverse_fastq_file ) {
        $files{paired_fastq_files} = [ $forward_fastq_file, $reverse_fastq_file ];
    }
    elsif ( -s $forward_fastq_file ) { # forward exists, reverse does not
        $self->error_message("Foward fastq ($forward_fastq_file) for library ($library_id) exists, but the reverse ($reverse_fastq_file) does not.");
        return;
    }
    elsif ( -s $reverse_fastq_file ) { # reverse exists, forward does not
        $self->error_message("Reverse fastq ($reverse_fastq_file) for library ($library_id) exists, but the forward ($forward_fastq_file) does not.");
        return;
    }

    if ( -s $fragment_fastq_file ) {
        $files{fragment_fastq_file} = $fragment_fastq_file;
    }

    return %files;
}

sub existing_assembler_input_files {
    my $self = shift;

    my @libraries = $self->libraries_with_existing_assembler_input_files;
    return if not @libraries;

    my @files;
    for my $library ( @libraries ) {
        push @files, @{$library->{paired_fastq_files}} if exists $library->{paired_fastq_files};
        push @files, $library->{fragment_fastq_files} if exists $library->{fragment_fastq_file};
    }

    return @files;
}

sub end_one_fastq_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.input_1.fastq';
}

sub end_two_fastq_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.input_2.fastq';
}

sub soap_config_file {
    return $_[0]->data_directory.'/config_file';
}

sub soap_scaffold_sequence_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.scafSeq';
}

sub soap_output_file_for_ext {
    return $_[0]->soap_output_dir_and_file_prefix.'.'.$_[1];
}

sub contigs_fasta_file {
    return $_[0]->edit_dir.'/'.$_[0]->file_prefix.'.contigs.fa';
}

sub supercontigs_fasta_file {
    return $_[0]->edit_dir.'/'.$_[0]->file_prefix.'.scaffolds.fa';
}

sub supercontigs_agp_file {
    return $_[0]->edit_dir.'/'.$_[0]->file_prefix.'.agp';
}

1;

