package Genome::InstrumentData::Command::Dacc;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::InstrumentData::Command::Dacc {
    is  => 'Command',
    is_abstract => 1,
    has => [
        sra_sample_id => {
            is => 'Text',
            is_input => 1,
            shell_args_position => 1,
            doc => 'SRA id to download and import from the DACC.',
        },
        format => {
            is => 'Text',
            is_input => 1,
            shell_args_position => 2,
            valid_values => [ valid_formats() ],
            doc => 'Format of the SRA id to download.',
        },
        validate_md5 => {
            is => 'Boolean',
            default_value => 1,
            doc => 'Validate MD5 for data files.',
        },
        # sample
        _sample => { is_optional => 1, },
        _library => { is_optional => 1, },
        # inst data
        _instrument_data => { is => 'Array', is_optional => 1, },
        _main_instrument_data => { 
            calculate_from => '_instrument_data',
            calculate => q| return $_instrument_data->[0]; |,
        },
        _allocation => { via => '_main_instrument_data', to => 'disk_allocations' },
        _absolute_path => { via => '_allocation', to => 'absolute_path' },
        # dl directory
        _dl_directory => {
            calculate_from => [qw/ _absolute_path sra_sample_id /], 
            calculate => q| return $_absolute_path.'/'.$sra_sample_id |,
        },
        _dl_directory_exists => {
            calculate_from => [qw/ _dl_directory /], 
            calculate => q| return -d $_dl_directory ? $_dl_directory : undef; |,
        },
    ],
};

sub __display_name__ {
    return $_[0]->sra_sample_id.' '.$_[0]->format;
}

#< HELP >#
sub help_brief {
    return 'Donwload and import from the DACC';
}

sub help_detail {
    return help_brief();
}
#<>#

#< FORMATS >#
sub formats_and_info {
    return (
        fastq => {
            sequencing_platform => 'solexa',
            import_format => 'sanger fastq',
            dacc_location => '/WholeMetagenomic/02-ScreenedReads/ProcessedForAssembly',
            destination_file => 'archive.tgz',
            kb_to_request => 100_000_000, # 100 GiB
            instrument_data_needed => 2,
        },
        sff => {
            sequencing_platform => '454',
            dacc_location => '/WholeMetagenomic/02-ScreenedReads/ProcessedForAssembly',
            destination_file => 'all_sequences.sff',
            kb_to_request => 15_000_000, # 15 GiB 
            instrument_data_needed => 2,
        },
        bam => {
            sequencing_platform => 'solexa',
            dacc_location => '/WholeMetagenomic/05-Analysis/ReadMappingToReference',
            destination_file => 'all_sequences.bam',
            kb_to_request => 20_000_000, # 20 GiB
            instrument_data_needed => 1,
        }
    );
}

sub valid_formats {
    my %formats = formats_and_info();
    return sort { $a cmp $b} keys %formats;
}

sub import_format {
    my $self = shift;
    my %formats = formats_and_info();
    return $formats{ $self->format }->{import_format} || $self->format;
}

sub sequencing_platform {
    my $self = shift;
    my %formats = formats_and_info();
    return $formats{ $self->format }->{sequencing_platform};
}

sub dacc_location {
    my $self = shift;
    my %formats = formats_and_info();
    return $formats{ $self->format }->{dacc_location};
}

sub destination_file_name {
    my $self = shift;
    my %formats = formats_and_info();
    return $formats{ $self->format }->{destination_file};
}

sub destination_file {
    my $self = shift;
    return $self->_absolute_path.'/'.$self->destination_file_name;
}

sub kb_to_request {
    my $self = shift;
    my %formats = formats_and_info();
    return $formats{ $self->format }->{kb_to_request};
}

sub instrument_data_needed {
    my $self = shift;
    my %formats = formats_and_info();
    return $formats{ $self->format }->{instrument_data_needed};
}

sub has_instrument_data_been_imported {
    my $self = shift;

    my $instrument_data = $self->_instrument_data;
    Carp::confess('No instruemnt data found to check if has been imported') if not $instrument_data;

    my @already_imported;
    for my $instrument_data ( @$instrument_data ) {
        my $data_file = $instrument_data->archive_path;
        next if not -e $data_file;
        push @already_imported, $instrument_data;
    }

    return if not @already_imported;

    $self->status_message('It appears that sample ('.$self->sra_sample_id.') '.$self->format.' has already been imported. These instrument data have a data file: '.join(' ', map { $_->id } @already_imported));

    return 1;
}

sub existing_data_files {
    my $self = shift;

    my $dl_directory = $self->_dl_directory_exists;
    return if not $dl_directory;

    my $format = $self->format;
    return sort { $a cmp $b } grep { $_ !~ /md5|xml/i } glob($dl_directory.'/*'.$self->format.'*');
}
#<>#

#< SAMPLE >#
sub _get_sample {
    my $self = shift;

    $self->status_message('Get sample...');

    my $sample = Genome::Sample->get(name => $self->sra_sample_id);
    return if not defined $sample;
    $self->_sample($sample);
    $self->status_message('Sample: '.join(' ',  map { $sample->$_ } (qw/ id name /)));

    my $library = $self->_get_or_create_library;
    return if not $library;
    return if not $self->_library;

    return $self->_sample;
}

sub _create_sample {
    my $self = shift;

    my $sra_sample_id = $self->sra_sample_id;
    if ( $sra_sample_id !~ /^SRS/ ) {
        $self->error_message("Invalid sra sample id: $sra_sample_id");
        return;
    }

    $self->status_message("Create sample for $sra_sample_id");

    my $sample = Genome::Sample->create(
        name => $sra_sample_id,
        extraction_label => $self->sra_sample_id,
        cell_type => 'unknown',
    );

    if ( not defined $sample ) {
        $self->error_message("Cannot create sample for $sra_sample_id");
        return;
    }
    if ( not UR::Context->commit ) {
        $self->error_message('Cannot commit sample');
        return;
    }
    $self->_sample( $sample );
    $self->status_message('Sample: '.join(' ',  map { $sample->$_ } (qw/ id name /)));

    my $library = $self->_get_or_create_library;
    return if not $library;

    $self->status_message('Create sample...OK');

    return $self->_sample;
}

sub _get_or_create_library {
    my $self = shift;

    my $sample = $self->_sample;
    my $library_name = $sample->name.'-extlibs';
    my $library = Genome::Library->get(name => $library_name);
    if ( not $library ) {
        $library = Genome::Library->create(
            name => $library_name,
            sample_id => $sample->id,
        );
        if ( not $library ) {
            $self->error_message('Cannot create library: '.$library_name);
            return;
        }
        if ( not UR::Context->commit ) {
            $self->error_message('Cannot commit library: '.$library_name);
            return;
        }
    }
    $self->_library($library);

    $self->status_message('Library: '.join(' ',  map { $self->_library->$_ } (qw/ id name /)));

    return $self->_library;
}
#<>#

#< INST DATA >#
sub _get_instrument_data {
    my $self = shift;

    $self->status_message('Get instrument data...');

    my @instrument_data = Genome::InstrumentData::Imported->get(
        sample_name => $self->sra_sample_id,
        import_source_name => 'DACC',
        import_format => $self->import_format,
    );
    return if not @instrument_data;
    $self->_instrument_data(\@instrument_data);

    if ( not $self->_allocation ) { # main allocation for downloading
        my $allocation = $self->_create_instrument_data_allocation(
            instrument_data => $instrument_data[0],
            kilobytes_requested => $self->kb_to_request,
        );
        return if not $allocation;
    }

    $self->status_message('Instrument data: '.join(' ', map { $_->id } @{$self->_instrument_data}));
    $self->status_message('Absolute path: '.$self->_absolute_path );

    return $self->_instrument_data;
}

sub _create_instrument_data {
    my ($self, %params) = @_;

    Carp::confess('No kb to request when creating instrument data.') if not $params{kilobytes_requested};

    my $instrument_data = $self->_instrument_data;
    $instrument_data ||= [];
    my $instrument_data_cnt = scalar @$instrument_data;

    $self->status_message('Create instrument data...');

    my $instrument_datum = Genome::InstrumentData::Imported->create(
        sample_id => $self->_sample->id,
        sample_name => $self->sra_sample_id,
        library_id => $self->_library->id,
        sra_sample_id => $self->sra_sample_id, 
        sequencing_platform => 'solexa',
        import_format => $self->import_format,
        import_source_name => 'DACC',
        original_data_path => 0, 
        description => 'new',
        subset_name => $instrument_data_cnt + 1,
    );

    if ( not $instrument_datum ) {
        $self->error_message('Cannot create main instrument data for sra sample id: '.$self->sra_sample_id);
        return;
    }

    if ( not UR::Context->commit ) {
        $self->error_message('Cannot commit main instrument data.');
        return;
    }

    push @$instrument_data, $instrument_datum;
    $self->_instrument_data($instrument_data);
    
    $params{instrument_data} = $instrument_datum;
    my $allocation = $self->_create_instrument_data_allocation(%params);
    return if not $allocation;

    $self->status_message('Instrument data: '.join(' ', map { $_->id } @{$self->_instrument_data}));
    $self->status_message('Absolute path: '.$self->_absolute_path );

    $self->status_message('Create instrument data...OK');

    return $self->_instrument_data;
}

sub _create_instrument_data_allocation {
    my ($self, %params) = @_;

    $self->status_message('Create instrument data allocation...');

    my $instrument_data = $params{instrument_data};
    Carp::confess('No instrument data given to create allocation') if not $instrument_data;

    my $kilobytes_requested = $params{kilobytes_requested};
    Carp::confess('No kilobytes requested given to create allocation') if not $kilobytes_requested;

    my $allocation = $instrument_data->disk_allocations;
    if ( defined $allocation ) {
        $self->status_message('Allocation already exists for instrument data: '.$instrument_data->id);
        return;
    }

    $allocation = Genome::Disk::Allocation->allocate(
        owner_id => $instrument_data->id,
        owner_class_name => $instrument_data->class,
        disk_group_name => 'info_alignments',
        allocation_path => 'instrument_data/imported/'.$instrument_data->id,
        kilobytes_requested => $kilobytes_requested,
    );

    if ( not $allocation ) {
        $self->error_message('Could not create disk allocation for instrument data: '.$instrument_data->id);
        return;
    }

    if ( not $allocation ) {
        $self->error_message('No allocation for instrument data: '.$instrument_data->id);
    }

    $self->status_message('Create instrument data allocation...OK');

    return $allocation;
}
#<>#

#< MD5 >#
sub _validate_md5 {
    my $self = shift;

    if ( not $self->validate_md5 ) {
        $self->status_message('Skip validate md5...');
        return 1;
    }

    my @data_files = $self->existing_data_files;
    if ( not @data_files ) {
        $self->error_message('No data files found for format: '.$self->format);
        return;
    }

    my $md5 = Genome::InstrumentData::Command::Dacc::MD5->create(
        data_files => \@data_files,
        format => $self->format,
        confirmed_md5_file => $self->_dl_directory.'/confirmed.md5',
    );

    if ( not $md5 ) {
        $self->error_message('Cannot create MD5 validate object.');
        return;
    }

    if ( not $md5->execute ) {
        $self->error_message('Failed to validate MD5');
        return;
    }

    return 1;
}
#<>#

#< Update Library >#
sub _update_library {
    my $self = shift;

    my $dl_directory = $self->_dl_directory;
    if ( not -d $dl_directory ) {
        $self->error_message("Download directory ($dl_directory) does not exist.");
        return;
    }

    my @xml_files = glob($dl_directory.'/*.xml');
    if ( not @xml_files ) { # ok
        $self->status_message('Attempt to update library, but no XMLs in download directory. This is OK.');
        return 1;
    }

    my $update_library = Genome::InstrumentData::Command::Dacc::UpdateLibrary->create(
        sra_sample_id => $self->sra_sample_id,
        xml_files => \@xml_files,
    );

    if ( not $update_library ) {
        $self->error_message('Cannot create update library object.');
        return;
    }

    if ( not $update_library->execute ) {
        $self->error_message('Failed to update library');
        return;
    }

    return 1;
}
#<>#

1;

