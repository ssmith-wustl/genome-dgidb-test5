package Genome::InstrumentData::Alignment::Imported;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Alignment::Imported {
    is => ['Genome::InstrumentData::Alignment'],
    has_constant => [
        aligner_name => { value => 'imported' },
    ],
};

sub _resolve_subclass_name_for_aligner_name {
	return 'Genome::InstrumentData::Alignment::Imported';
}


sub alignment_file_paths {
    my $self = shift;
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    return grep { -e $_ && $_ !~ /aligner_output/ }
            glob($self->alignment_directory .'/*.bam*');
}

sub alignment_bam_file_paths {
    my $self = shift;
    my $align_dir = $self->alignment_directory;
    
    return unless $align_dir and -d $align_dir;
    return grep { -e $_ && $_ !~ /merged_rmdup/} glob($self->alignment_directory .'/*.bam');
}

sub alignment_file {
    my $self = shift;
    return $self->alignment_directory .'/all_sequences.bam';
}


sub find_or_generate_alignment_data {
    my $self = shift;
  
    unless ($self->verify_alignment_data) {
        $self->status_message("Could not validate alignments.  Running aligner.");
        return $self->_run_aligner();
    } 
    else {
        $self->status_message("Existing alignment data is available and deemed correct.");
        $self->status_message("Alignment directory: ".$self->alignment_directory);
    }

    return 1;
}


sub verify_alignment_data {
    my $self = shift;
    my $alignment_dir = $self->alignment_directory;
    
    return unless $alignment_dir and -d $alignment_dir;
    
    my $lock;
    unless ($self->_resource_lock) {
	    $lock = $self->lock_alignment_resource;
    } 
    else {
	    $lock = $self->_resource_lock;
    }
    
    unless (-e $self->alignment_file) {
	    $self->status_message('No imported file found in alignment directory: '. $alignment_dir . ' missing file: ' . $self->alignment_file);
	    return;
    }

    unless ($self->unlock_alignment_resource) {
        $self->error_message('Failed to unlock alignment resource '. $lock);
        return;
    }
 
    return 1;
}


sub _run_aligner {
    my $self = shift;
    my $lock;
    
    unless ($self->_resource_lock) {
	    $lock = $self->lock_alignment_resource;
    } 
    else {
	    $lock = $self->_resource_lock;
    }

    my $instrument_data = $self->instrument_data;
    my $alignment_file  = $self->alignment_file;
    my $original_file   = $instrument_data->original_data_path;

    Genome::DataSource::GMSchema->disconnect_default_dbh; 

    unless (Genome::Utility::FileSystem->copy_file($original_file, $alignment_file)) {
        $self->error_message("Failed to copy imported original file: $original_file to $alignment_file");
        return;
    }
    
    my $alignment_allocation = $self->get_allocation;

    if ($alignment_allocation) {
        unless ($alignment_allocation->reallocate) {
            $self->error_message('Failed to reallocate disk space for disk allocation: '. $alignment_allocation->id);
            $self->die_and_clean_up($self->error_message);
        }
    }
    
    unless ($self->unlock_alignment_resource) {
        $self->error_message('Failed to unlock alignment resource '. $lock);
        return;
    }
    
    return 1;
}


1;
