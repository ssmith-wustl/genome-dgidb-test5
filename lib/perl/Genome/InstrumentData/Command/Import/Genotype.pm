package Genome::InstrumentData::Command::Import::Genotype;

use strict;
use warnings;

use Genome;

use File::Copy;
use File::Basename;
use Data::Dumper;
use IO::File;

class Genome::InstrumentData::Command::Import::Genotype {
    is  => 'Genome::Command::Base',
    has => [
        source_data_file => {
            is => 'Text',
            doc => 'source data path of import data file',
        },
        library => {
            is => 'Genome::Library',
            doc => 'Define this OR sample OR both if you like.',
            is_optional => 1,
        },
        sample => {
            is => 'Genome::Sample',
            doc => 'Define this OR library OR both if you like.',
            is_optional => 1,
        },
        import_source_name => {
            is => 'Text',
            doc => 'source name for imported file, like Broad Institute',
            is_optional => 1,
        },
        sequencing_platform => {
            is => 'Text',
            doc => 'sequencing platform of import data. Ex: infinium, affymetrix',
        },
        description  => {
            is => 'Text',
            doc => 'General description of the genotype data',
        },
        read_count => {
            is => 'Number',
            doc => 'The number of reads in the genotype file',
            is_optional => 1,
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            doc => 'Build of the reference against which the genotype file was produced.',
        },
        define_model => {
            is=>'Boolean',
            doc => 'Create a goldSNP file from the imported genotype and define/build a GenotypeMicroarray model.',
            default_value => 0,
            is_optional => 1,
        },
        _model => { is_optional => 1, },
        _instrument_data => { is_optional => 1, },
    ],
};

sub generated_instrument_data_id {
    return $_[0]->_instrument_data->id;
}

sub execute {
    my $self = shift;

    my $file_ok = $self->_validate_genotype_file;
    return if not $file_ok;

    my $reference_sequence_build = $self->reference_sequence_build;
    if ( not $reference_sequence_build ) {
        $self->error_message('No reference sequence build given');
        return;
    }

    my $resolve_sample_library = $self->_resolve_sample_and_library;
    return if not $resolve_sample_library;

    if ( $self->define_model ) {
        my $model = $self->_create_model;
        return if not $model;
    }

    my $instrument_data = $self->_create_instrument_data;
    return if not $instrument_data;

    my $allocation = $self->_resolve_allocation;
    return if not $allocation;

    my $copy_and_md5 = $self->_copy_and_validate_md5;
    return if not $copy_and_md5;

    if ( $self->define_model ) {
        my $add_and_build = $self->_add_instrument_data_to_model_and_build($instrument_data);
        return if not $add_and_build;
    }

    return 1;
}

sub _validate_genotype_file {
    my $self = shift;

    $self->status_message("Validate genotype file");

    my $file = $self->source_data_file;
    if ( not $file ) { 
        $self->error_message("No genotype file given");
        return;
    }

    $self->status_message("Genotype file: $file");

    if ( not -s $file ) {
        $self->error_message("Genotype file ($file) does not exist");
        return;
    }

    # Format, space separated:
    # chr pos alleles
    my $fh = IO::File->new($file, 'r');
    if ( not $fh ) {
        $self->error_message("Cannot open genotype file ($file): $!");
        return;
    }
    my $line = $fh->getline;
    if ( not $line ) {
        $self->error_message();
        return;
    }
    chomp $line;
    my @tokens = split(/\s+/, $line);
    if ( not @tokens or @tokens != 3 ) {
        $self->error_message('Genotype file ($file) is not in 3 column format');
        return;
    }
    $fh->close;

    $self->status_message("Validate genotype file...OK");

    return $file;
}

sub get_read_count {
    my $self = shift;
    my $line_count;
    $self->status_message("Now attempting to determine read_count by calling wc on the imported genotype.");
    my $file = $self->source_data_file;
    $line_count = `wc -l $file`;
    ($line_count) = split " ",$line_count;
    unless(defined($line_count)&&($line_count > 0)){
        $self->error_message("couldn't get a response from wc.");
        return;
    }
    return $line_count
}

sub _resolve_sample_and_library {
    my $self = shift;

    $self->status_message("Resolve sample and library");

    my $sample = $self->sample;
    my $library = $self->library;
    if ( $sample and $library and $sample->id ne $library->sample_id ) {
        $self->error_message('Library ('.$library->id.') sample id ('.$library->sample_id.') does not match given sample id ('.$sample->id.')');
        return;
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

    my $processing_profile = Genome::ProcessingProfile->get(2186707); # name => unknown/wugc
    if ( not $processing_profile ) {
        $self->error_message('Cannot find genotype microarray processing profile "unknown/wugc" to create model');
        return;
    }

    my %model_params = (
        processing_profile => $processing_profile,
        subject_id => $self->sample->id,
        subject_class_name => $self->sample->class,
        reference_sequence_build => $self->reference_sequence_build,
    );

    $self->status_message('Processing profile: '.$processing_profile->name);
    $self->status_message('Sample: '.$self->sample->name);
    $self->status_message('Reference build: '.$self->reference_sequence_build->__display_name__);

    my $model = Genome::Model::GenotypeMicroarray->get(%model_params);
    if ( $model ) {
        $self->error_message('Cannot create genotype microarray model because one exists for processing profile ('.$processing_profile->name.'), sample ('.$self->sample->name.') and reference sequence build ('.$self->reference_sequence_build->name.')');
        return;
    }
    $model = Genome::Model::GenotypeMicroarray->create(%model_params);
    if ( not $model ) {
        $self->error_message('Cannot create genotype microarray model');
        return;
    }

    $self->status_message('Create genotype model: '.$model->id);

    return $self->_model($model);
}

sub _create_instrument_data {
    my $self = shift;

    $self->status_message('Create instrument data');

    my $read_count = $self->read_count;
    if ( not $read_count ) {
        my $read_count = $self->get_read_count();
        if( not $read_count ){
            $self->error_message("No read count was specified and none could be calculated from the file.");
            return;
        }
        $self->read_count($read_count);
    }

    my $instrument_data = Genome::InstrumentData::Imported->create(
        library => $self->library,
        sequencing_platform => $self->sequencing_platform,
        description => $self->description,
        import_format => 'genotype file',
        import_source_name => $self->import_source_name,
        read_count => $read_count,
        original_data_path => $self->source_data_file,
    );
    if ( not $instrument_data ) {
       $self->error_message('Failed to create imported instrument data');
       return;
    }

    $self->_instrument_data($instrument_data);

    $self->status_message('Instrument data: '.$instrument_data->id);

    return $instrument_data;
}

sub _resolve_allocation {
    my $self = shift;

    $self->status_message('Resolve allocation');

    my $instrument_data = $self->_instrument_data;
    Carp::confess('No instrument data set to resolve allocation') if not $instrument_data;

    my $file = $self->source_data_file;
    my $file_sz = -s $file;
    my $kb_requested = $file_sz * 1.5;
    my $allocation = Genome::Disk::Allocation->allocate(
        disk_group_name     => 'info_alignments',     #'info_apipe',
        allocation_path     => 'instrument_data/imported/'.$instrument_data->id,
        kilobytes_requested => $kb_requested,
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

sub _copy_and_validate_md5 {
    my $self = shift;

    $self->status_message("Copy and validate MD5");

    my $file = $self->source_data_file;
    my $md5 = Genome::Sys->md5sum($file);
    if ( not $md5 ) {
        $self->error_message('Failed to get md5 for source data file: '.$file);
        return;
    }
    $self->status_message('MD5: '.$md5);

    my $dest_file = $self->_instrument_data->genotype_microarray_file_for_reference_sequence_build(
        $self->reference_sequence_build,
    );
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
    my $build_start = Genome::Model::Build::Command::Start->create(
        models => [ $model ],
        server_dispatch => 'inline',
        job_dispatch => 'inline',
    );
    if ( not $build_start ) {
        $self->error_message('Cannot create build start command for model '.$model->__display_name__);
        return
    }
    $build_start->dump_status_messages(1);
    if ( not $build_start->execute ) {
        $self->error_message('Cannot execute build start command for model '.$model->__display_name__);
        return;
    }
    $self->status_message('Build OK');

    return 1;
}

1;

