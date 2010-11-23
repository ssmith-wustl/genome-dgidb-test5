package Genome::InstrumentData::Command::Dacc;

use strict;
use warnings;

use Genome;

require Cwd;
use Data::Dumper 'Dumper';
require File::Basename;
require File::Path;
require XML::LibXML;

class Genome::InstrumentData::Command::Dacc {
    is  => 'Command',
    is_abstract => 1,
    has => [
        sra_sample_id => {
            is => 'Text',
            is_input => 1,
            shell_args_position => 1,
            doc => 'SRA id to download processed reads from the DACC.',
        },
        format => {
            is => 'Text',
            is_input => 1,
            shell_args_position => 2,
            valid_values => [ valid_formats() ],
            doc => 'SRA id to download processed reads from the DACC.',
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
        # misc
        _confirmed_md5_file => {
            calculate_from => [qw/ _dl_directory /],
            calculate => q| return $_dl_directory.'/confirmed.md5'; |,
        },
    ],
};

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
            kb_to_request => 100_000_000, # 100 GiB, will go down
            instrument_data_needed => 2,
        },
        sff => {
            sequencing_platform => '454',
            dacc_location => '??', #FIXME
            destination_file => '??', #FIXME
            kb_to_request => 20_000_000, # 20 GiB FIXME
            instrument_data_needed => 1,
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

    my $destination_file = $self->destination_file;
    if ( -e $self->destination_file ) {
        $self->status_message('It appears that sample ('.$self->sra_sample_id.') '.$self->format.' has already been imported. The final destination file exists: '.$destination_file);
        return 1;
    }

    return;
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
            sample_id => $sample->id,
            library_name => $library_name,
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

    return $self->_instrument_data;
}

sub _create_instrument_data {
    my ($self, %params) = @_;

    my $instrument_data = $self->_get_instrument_data;
    my $instrument_data_cnt = ( $instrument_data ) ? scalar @$instrument_data : 0;
    my $instrument_data_needed = $self->instrument_data_needed;
    if ( $instrument_data_cnt >= $instrument_data_needed ) {
        # This prevents accidental creation of extra inst data
        return $self->_instrument_data;
    }

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
    $params{kilobytes_requested} = $self->kb_to_request if not $params{kilobytes_requested};
    my $allocation = $self->_create_instrument_data_allocation(%params);
    return if not $allocation;

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

#< Files, Dirs >
sub _xml_files {
    my $self = shift;

    my $dl_directory = $self->_dl_directory;
    return if not -d $dl_directory;

    return glob($dl_directory.'/*.xml');

}
#<>#

#< Read Count >#
sub _read_count_for_fastq {
    my ($self, $fastq) = @_;

    my $line_count = `wc -l < $fastq`;
    if ( $? or not $line_count ) {
        $self->error_message("Line count on fastq ($fastq) failed.");
        return;
    }

    chomp $line_count;
    if ( ($line_count % 4) != 0 ) {
        $self->error_message("Line count ($line_count) on fastq ($fastq) not divisble by 4.");
        return;
    }

    return $line_count / 4;
}
#<>#

#< MD5 >#
sub _validate_md5 {
    my $self = shift;

    $self->status_message('Validate md5...');

    my %dacc_md5 = $self->_load_dacc_md5;
    return if not %dacc_md5;

    my %confirmed_md5 =$self->_load_confirmed_md5;
    return if not %confirmed_md5;

    for my $file ( keys %dacc_md5 ) {
        if ( $dacc_md5{$file} ne $confirmed_md5{$file} ){
            $self->error_message("MD5 for file ($file) does not match: $dacc_md5{$file} <=> $confirmed_md5{$file}");
            return;
        }
    }

    $self->status_message('Validate md5...OK');

    return 1;
}

sub _load_dacc_md5 {
    my $self = shift;

    $self->status_message('Load DACC md5...');

    my $cwd = Cwd::cwd();
    my $dl_directory = $self->_dl_directory;
    chdir $dl_directory;

    my $sra_sample_id = $self->sra_sample_id;
    my @md5_files = glob('*.md5');
    my %files_and_md5;
    for my $md5_file ( @md5_files ) {
        my %current_files_and_md5 = $self->_load_md5($md5_file);
        my $matching_file = $md5_file;
        $matching_file =~ s/\.md5$//;
        for my $file ( keys %current_files_and_md5 ) {
            my $key = ( -e $file )
            ? $file # file exists for this md5
            : $matching_file; # file in md5 does not exist, assume we use the matching file name
            if ( exists $files_and_md5{$key} and $files_and_md5{$key} ne $current_files_and_md5{$file} ){
                # overwriting md5 for same file name, and it's different
                Carp::confess('Duplicate MD5 does not match for file: '.$key);
            }
            $files_and_md5{$key} = $current_files_and_md5{$file};
        }
    }

    chdir $cwd;

    $self->status_message('Load DACC md5...OK');
    print Dumper

    return %files_and_md5;
}

sub _load_confirmed_md5 {
    my $self = shift;

    $self->status_message('Load confirmed md5...');

    my $md5_file = $self->_confirmed_md5_file;
    if ( not -e $md5_file ) {
        my $generate = $self->_generate_md5;
        return if not $generate;
    }

    my %files_and_md5 = $self->_load_md5($md5_file);
    if ( not %files_and_md5 ) {
        $self->error_message("Cannot load confirmed md5 from file: $md5_file");
        return;
    }

    $self->status_message('Load confirmed md5...OK');

    return %files_and_md5;
}

sub _load_md5 {
    my ($self, $md5_file) = @_;

    my $md5_fh = eval{ Genome::Utility::FileSystem->open_file_for_reading($md5_file); };
    if ( not defined $md5_fh ) {
        $self->error_message("Cannot open md5 file ($md5_file): $@");
        return;
    }
    my $sra_sample_id = $self->sra_sample_id;
    my %files_and_md5;
    while ( my $line = $md5_fh->getline ) {
        chomp $line;
        my ($md5, $file) = split(/\s+/, $line);
        $file =~ s#^$sra_sample_id/##;
        $files_and_md5{$file} = $md5;
    }

    return %files_and_md5;
}

sub _generate_md5 {
    my $self = shift;

    $self->status_message('Generate md5...');

    my %dacc_files_and_md5 = $self->_load_dacc_md5;
    return if not %dacc_files_and_md5;

    my $md5_file = $self->_confirmed_md5_file;
    unlink $md5_file if -e $md5_file;

    my $cwd = Cwd::cwd();
    my $dl_directory = $self->_dl_directory;
    chdir $dl_directory;

    for my $file ( keys %dacc_files_and_md5 ) {
        my $cmd = "md5sum $file >> $md5_file";
        $self->status_message("MD5 command: $cmd");
        my $rv = eval{ Genome::Utility::FileSystem->shellcmd(cmd => $cmd); };
        if ( not $rv ) {
            $self->error_message("Failed to run md5sum on $file: $@");
            return;
        }
    }
    chdir $cwd;

    $self->status_message('Generate md5...OK');

    return 1;
}
#<>#

1;

