package Genome::InstrumentData::Command::Import::Microarray::Base;

use strict;
use warnings;

use Genome;

use File::Copy;
use File::Basename;
use Data::Dumper;
use IO::File;

class Genome::InstrumentData::Command::Import::Microarray::Base {
    is  => 'Genome::Command::Base',
    is_abstract => 1,
    has => [
        original_data_path => {
            is => 'Text',
            doc => 'Directory or file(s) (comma separated) to import.',
        },
        library => {
            is => 'Genome::Library',
            doc => 'Library to associate with this microarray data. If not given, a library from the sample will be used or created.',
            is_optional => 1,
        },
        sample => {
            is => 'Genome::Sample',
            doc => 'Sample to associate with this microarray data. If not given, it will be resolved via the library.',
            is_optional => 1,
        },
        import_source_name => {
            is => 'Text',
            doc => 'Center name where this data was generated. Ex: wugc, broad...',
            is_optional => 1,
            default_value => 'wugc',
        },
        sequencing_platform => {
            is => 'Text',
            doc => 'sequencing platform of import data. Ex: infinium, affymetrix',
        },
        description  => {
            is => 'Text',
            doc => 'General description of the genotype data',
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            doc => 'Build of the reference against which the genotype file was/will be produced.',
        },
        _model => { is_optional => 1, },
        _instrument_data => { is_optional => 1, },
        _kb_requested => { is_optional => 1, },
    ],
};

sub generated_instrument_data_id {
    return $_[0]->_instrument_data->id;
}

sub execute {
    my $self = shift;

    my $data_path_ok = $self->_validate_original_data_path_and_set_kb_requested;
    return if not $data_path_ok;

    my $reference_sequence_build = $self->reference_sequence_build;
    if ( not $reference_sequence_build ) {
        $self->error_message('No reference sequence build given');
        return;
    }

    my $resolve_sample_library = $self->_resolve_sample_and_library;
    return if not $resolve_sample_library;

    my $instrument_data = $self->_create_instrument_data;
    return if not $instrument_data;

    my $model = $self->_create_model;
    return if not $model;

    my $allocation = $self->_create_allocation;
    return if not $allocation;

    my $copy = $self->_copy_original_data_path;
    return $self->_deallocate if not $copy;

    my $unsorted_genotype_file = $self->_resolve_unsorted_genotype_file;
    return $self->_deallocate if not $unsorted_genotype_file;

    my $sort_ok = $self->_sort_genotype_file($unsorted_genotype_file);
    return $self->_deallocate if not $sort_ok;

    my $add_and_build = $self->_add_instrument_data_to_model_and_build($instrument_data);
    return $self->_deallocate if not $add_and_build;

    my $reallocate = eval{ $self->_instrument_data->disk_allocations->reallcoate; };

    return 1;
}

sub _validate_original_data_path_and_set_kb_requested {
    my $self = shift;
    
    my $kb_requested;
    my $original_data_path = $self->original_data_path;
    if ( -d $original_data_path ) {
        $kb_requested = Genome::Sys->directory_size_recursive($original_data_path);
    }
    else {
        for my $file ( split(',', $original_data_path) ) {
            if ( not -e $file ) {
                $self->error_message('Original data file does not exist: '.$file);
                return;
            }
            $kb_requested += -s $file;
        }
    }

    $kb_requested += 100_000; # to dump a genotype file
    $self->status_message("KB requested: $kb_requested");
    $self->_kb_requested($kb_requested);

    return 1;
}

sub process_imported_files {
    my $self = shift;
    return 1;
}

sub _resolve_sample_and_library {
    my $self = shift;

    $self->status_message("Resolve sample and library");

    my $sample = $self->sample;
    my $library = $self->library;
    if ( $sample and $library ) { 
        if ( $sample->id ne $library->sample_id ) {
            $self->error_message('Library ('.$library->id.') sample id ('.$library->sample_id.') does not match given sample id ('.$sample->id.')');
            return;
        }
    }
    elsif ( $sample ) { # get/create library
        my %library_params = (
            sample_id => $sample->id,
            name => $sample->name.'-microarraylib',
        );
        $library = Genome::Library->get(%library_params);
        if ( not $library ) {
            $library = Genome::Library->create(%library_params);
            if ( not $library ) {
                $self->error_message('Cannot create microarray library for sample: '.$sample->id);
                return;
            }
        }
        $self->library($library);
    }
    elsif ( $library ) { # get/set sample
        $sample = $library->sample;
        if ( not $sample ) { # should not happen
            $self->error_message('No sample ('.$sample->id.') for library: '.$library->id);
            return;
        }
        $self->sample($sample);
    }
    else {
        $self->error_message('Need sample or library to import genotype microarray');
        return;
    }

    $self->status_message('Resolve sample ('.$sample->id.') and library ('.$library->id.')');
    
    return 1;
}

sub _create_model {
    my $self = shift;

    $self->status_message('Create genotype model');

    my $processing_profile = Genome::ProcessingProfile::GenotypeMicroarray->get(instrument_type => $self->sequencing_platform);
    if ( not $processing_profile ) {
        $self->error_message('Cannot find genotype microarray processing profile for '.$self->sequencing_platform.' to create model');
        return;
    }

    $self->status_message('Processing profile: '.$processing_profile->name);
    $self->status_message('Sample: '.$self->sample->name);
    $self->status_message('Reference build: '.$self->reference_sequence_build->__display_name__);

    my $model = Genome::Model::GenotypeMicroarray->create(
        name => 'IMPORT_GM_PLACE_HOLDER',
        processing_profile => $processing_profile,
        subject_id => $self->sample->id,
        subject_class_name => $self->sample->class,
        reference_sequence_build => $self->reference_sequence_build,
    );
    if ( not $model ) {
        $self->error_message('Cannot create genotype microarray model');
        return;
    }
    my $name = $model->default_model_name(instrument_data => $self->_instrument_data);
    if ( not $name ) {
        $self->error_message('No default name for genotype microarray model');
        $model->delete;
        return;
    }
    $model->name($name);

    $self->status_message('Create genotype model: '.$model->id);

    return $self->_model($model);
}

sub _create_instrument_data {
    my $self = shift;

    $self->status_message('Create instrument data');

    my $instrument_data = Genome::InstrumentData::Imported->create(
        library => $self->library,
        sequencing_platform => $self->sequencing_platform,
        description => $self->description,
        import_format => 'genotype file',
        import_source_name => $self->import_source_name,
        original_data_path => $self->original_data_path,
    );
    if ( not $instrument_data ) {
       $self->error_message('Failed to create imported instrument data');
       return;
    }

    $self->_instrument_data($instrument_data);

    $self->status_message('Instrument data: '.$instrument_data->id);

    return $instrument_data;
}

sub _create_allocation {
    my $self = shift;

    $self->status_message('Create allocation');

    my $instrument_data = $self->_instrument_data;
    Carp::confess('No instrument data set to resolve allocation') if not $instrument_data;

    my $allocation = Genome::Disk::Allocation->allocate(
        disk_group_name     => 'info_alignments',
        allocation_path     => 'instrument_data/imported/'.$instrument_data->id,
        kilobytes_requested => $self->_kb_requested,
        owner_class_name    => $instrument_data->class,
        owner_id            => $instrument_data->id,
    );

    if ( not $allocation ) {
        $self->error_message('Failed to create disk allocation');
        return;
    }

    $self->status_message('Allocation: '.$allocation->id);

    return $allocation;
}

sub _copy_original_data_path {
    my $self = shift;

    my $original_data_path = $self->original_data_path;
    if ( -d $original_data_path ) {
        return $self->_copy_directory($original_data_path);
    }
    else {
        my @files = split(',', $original_data_path);
        for my $file ( @files ) {
            my $copy = $self->_copy_file($file);
            return if not $copy;
        }
        return 1;
    }
}

sub _copy_directory {
    my ($self, $directory) = @_;

    Carp::confess('No directory given to copy') if not $directory;
    Carp::confess("Directory $directory does not exist") if not -d $directory;
    $self->status_message("Copy directory: $directory");

    my $instrument_data = $self->_instrument_data;
    Carp::confess('No instruemnt data set to copy directory') if not $instrument_data;
    my $allocation = $instrument_data->disk_allocations;
    Carp::confess('No allocation for instrument data ('.$instrument_data->id.') to copy directory') if not $allocation;
    my $destination = $allocation->absolute_path;
    Carp::confess('No absolute path for allocation ('.$allocation->id.') to copy directory') if not $allocation;
    $self->status_message('Destination: '.$destination);

    my $size = Genome::Sys->directory_size_recursive($directory);             
    if ( not $size ) {
        $self->error_message("Failed to get size for $directory");
        return;
    }
    $self->status_message('Size: '.$size);

    local $File::Copy::Recursive::KeepMode = 0;
    my $copy = File::Copy::Recursive::dircopy($directory, $destination);
    if ( not $copy ) {
        $self->error_message("Failed to copy directory ($directory) to destination ($destination).");
        return;
    }

    my $new_size = Genome::Sys->directory_size_recursive($destination);             
    if ( not $new_size ) {
        $self->error_message("Failed to get new size for $destination");
        return;
    }
    $self->status_message('New size: '.$size);

    if ( $size != $new_size ) {
        $self->error_message("Failed to copy directory ($directory) to destination ($destination). The sizes do not match $size <=> $new_size");
        return;
    }

    return 1;
}

sub _copy_file {
    my ($self, $file) = @_;

    Carp::confess('No file given to copy and validate md5') if not $file;
    $self->status_message("Copy file: $file");

    my $md5 = Genome::Sys->md5sum($file);
    if ( not $md5 ) {
        $self->error_message('Failed to get md5 for source data file: '.$file);
        return;
    }
    $self->status_message('MD5: '.$md5);

    my $basename = File::Basename::basename($file);
    my $dest_file = $self->_instrument_data->data_directory.'/'.$basename;
    $self->status_message('Destination file: '.$dest_file);

    my $copy = File::Copy::copy($file, $dest_file);
    if ( not $copy ) {
        $self->error_message("Failed to copy $file to $dest_file");
        return;
    }
    my $dest_md5 = Genome::Sys->md5sum($dest_file);
    if ( not $dest_file ) {
        $self->error_message('Failed to get md5 for destination file: '.$dest_file);
        return;
    }
    $self->status_message('Destination MD5: '.$md5);

    if ( $md5 ne $dest_md5 ) {
        $self->error_message("Source MD5 ($md5) does not match destination MD5)");
        return;
    }

    $self->status_message("Copy and validate MD5...OK");

    return 1;
}

sub _add_instrument_data_to_model_and_build {
    my ($self, $instrument_data) = @_;

    my $model = $self->_model;

    $self->status_message('Add instrument data '.$instrument_data->id.' to model '.$model->__display_name__);
    my $add_ok = $model->add_instrument_data($instrument_data);
    if ( not $add_ok ) {
        $self->error_message('Cannot add genotype microarray instrument data to model '.$model->__display_name__);
        return;
    }
    $self->status_message('Add instrument data OK');

    $self->status_message('Build model '.$model->__display_name__);
    my $build = Genome::Model::Build->create(model => $model);
    if ( not $build) {
        $self->error_message("Failed to create build for model (".$model->name.", ID: ".$model->id.").");
        return;
    }
    $build->start(
        server_dispatch => 'inline',
        job_dispatch => 'inline',
    );
    if ( $build->status ne 'Succeeded' ) {
         $self->error_message("Build failed: " . $build->__display_name__);
         return;
    }
    $self->status_message('Build OK');

    return 1;
}

sub _sort_genotype_file {
    my ($self, $unsorted_genotype_file) = @_;

    $self->status_message('Sort genotype file');

    my $genotype_file = $self->_instrument_data->genotype_microarray_file_for_reference_sequence_build($self->reference_sequence_build);
    if ( not $genotype_file ) {
        $self->error_message('Failed to get gneotype microarray file name from instruemnt data');
        return;
    }
    $self->status_message('Genotype file:'. $genotype_file);
    $self->status_message('Unsorted genotype file:'. $unsorted_genotype_file);

    my $sort = Genome::Model::Tools::Snp::Sort->create(
        snp_file => $unsorted_genotype_file,
        output_file => $genotype_file,
    );
    if ( not $sort ) {
        unlink $unsorted_genotype_file;
        $self->error_message('Failed to create sort command');
        return;
    }
    $sort->dump_status_messages(1);
    if ( not $sort->execute ) {
        unlink $genotype_file;
        unlink $unsorted_genotype_file;
        $self->error_message('Failed to execute sort command');
        return;
    }
    $self->status_message("Sort genotype file...OK");

    return 1;
}

sub _deallocate {
    my $self = shift;

    my $instrument_data = $self->_instrument_data;
    return if not $instrument_data;

    my $allocation = $instrument_data->disk_allocations;
    return if not $allocation;

    $self->status_message('Deallocate');
    my $dealloc = eval{ $allocation->deallocate; };
    if ( $dealloc ) {
        $self->status_message('Deallocate...OK');
    }
    else {
        $self->error_message('Failed to deallocate! This is a rogue allocation: '.$allocation->id);
    }

    return;
}

1;

