package Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArrayMulti;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require File::Temp;
require IO::Dir;
require IO::File;

class Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArrayMulti {
    is => 'Genome::Command::Base',
    has => [
        original_data_path => {
            is => 'Text',
            doc => 'original data path of import data file(s): all files in path will be used as input',
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            doc => 'Build of the reference against which the genotype file was/will be produced.',
        },
        ucsc_array_file => {
            is => 'Text',
            is_optional => 1,
            default_value => "/gscmnt/sata135/info/medseq/dlarson/snpArrayIllumina1M",
        },
        exclude_samples => {
            is => 'Text',
            is_optional => 1,
            is_many => 1,
            doc => 'Do not import these samples.',
        },
        include_samples => {
            is => 'Text',
            is_optional => 1,
            is_many => 1,
            doc => 'Only import these samples.',
        }, 
        import_source_name => {
            is => 'Text',
            doc => 'Source of the microarray data. Ex: WUGC, Broad, TIGR...',
            is_optional => 1,
            default_value => 'WUGC',
        },
        description  => {
            is => 'Text',
            doc => 'General description of the genotype data',
        },
        sequencing_platform => { is => 'Text', is_param => 0, is_constant => 1, value => 'illumina', },
        _models => { is => 'Array', is_optional => 1, is_param => 0, },
    ],
    doc => 'import multiple illumina microarray data',
};

sub execute {
    my $self = shift;

    my ($master_file_name, $sample_map_file_name) = $self->_resolve_master_file_and_sample_map;
    return if not $master_file_name or not $sample_map_file_name;

    my $output_directory = $self->_create_genotypes_from_master_file($master_file_name);
    return if not $output_directory;

    my @samples = $self->_resolve_samples($sample_map_file_name);
    return if not @samples;

    for my $sample_info ( @samples ) {
        $sample_info->{genotype_file} = $output_directory.'/'.$sample_info->{external_name}.'.genotype';
    }

    my $import = $self->_import_samples(@samples);
    return if not $import;

    return 1;
}

sub _resolve_master_file_and_sample_map {
    my $self = shift;

    $self->status_message('Resolve call file and sample map');

    my $io_dir = IO::Dir->new($self->original_data_path);
    if ( not $io_dir ) {
        $self->error_message('Failed to open original path: '.$self->original_data_path);
        return;
    }
    $io_dir->read; $io_dir->read;
    my ($master_file_name, $sample_map_file_name);
    while ( my $file = $io_dir->read ) {
        if ($file =~ /FinalReport\.(txt|csv)/) {
            $master_file_name = $file;
        }
        elsif ($file =~ /Sample_Map/) {
            $sample_map_file_name = $file;
        }
        last if $master_file_name and $sample_map_file_name;
    }
    if ( not $master_file_name ) {
        $self->error_message('Could not find master genotype file in original data path: '.$self->original_data_path);
        return;
    }
    if ( not $sample_map_file_name ) {
        $self->error_message('Could not find sample map file in original data path: '.$self->original_data_path);
        return;
    }
    $self->status_message("Master file name: $master_file_name");
    $self->status_message("Sample map name: $sample_map_file_name");

    $self->status_message('Resolve call file and sample map...OK');

    return ($master_file_name, $sample_map_file_name);
}

sub _create_genotypes_from_master_file {
    my ($self, $master_file_name) = @_;

    Carp::confess('No master file name given') if not $master_file_name;

    $self->status_message('Create genotypes from master file');

    my $master_file = $self->original_data_path.'/'.$master_file_name;
    $self->status_message('Master file: '.$master_file);

    my $temp_dir = File::Temp::tempdir(CLEANUP => 1); 
    $self->status_message('Temp dir: '.$temp_dir);
    my $tool = Genome::Model::Tools::Array::CreateGenotypesFromBeadstudioCalls->create(
        genotype_file => $master_file,
        output_directory => $temp_dir, 
        ucsc_array_file => $self->ucsc_array_file,
    );
    if ( not $tool ) {
        $self->error_message('Failed to create "create genotypes from beadstudio calls" tool');
        return;
    }
    $tool->dump_status_messages(1);
    if ( not $tool->execute ) {
        $self->error_message('Failed to execute "create genotypes from beadstudio calls" tool');
        return;
    }

    $self->status_message('Create genotypes from master call file...OK');

    return $temp_dir
}

sub _resolve_samples {
    my ($self, $sample_map_file_name) = @_;

    Carp::confess('No sample map file name given') if not $sample_map_file_name;

    $self->status_message('Resolve samples and genotype files');

    my $sample_map_file = $self->original_data_path.'/'.$sample_map_file_name;
    $self->status_message('Sample map file: '.$sample_map_file);

    my $this_sample_should_be_excluded;
    if ( $self->exclude_samples and $self->include_samples ) {
        $self->error_message('Cannot use included and excluded sample names at the same time.');
        return;
    }
    elsif ( $self->exclude_samples ) {
        $self->status_message('Exclude samples: '.join(' ', $self->exclude_samples));
        $this_sample_should_be_excluded = sub{
            return grep { $_[0] eq $_ } $self->exclude_samples;
        };
    }
    elsif ( $self->include_samples ) {
        $self->status_message('Include samples: '.join(' ', $self->include_samples));
        $this_sample_should_be_excluded = sub{
            return not grep { $_[0] eq $_ } $self->include_samples;
        };
    }
    else {
        $self->status_message('Include all samples');
        $this_sample_should_be_excluded = sub{ return; };
    }

    my $fh = IO::File->new($sample_map_file, "r");
    if ( not $fh ) {
        $self->error_message("Could not open sample map file ($sample_map_file): $!");
        return;
    }

    my $header = $fh->getline;
    my $split_char;
    if ( $header =~ /\,/ ) {
        $split_char = ',';
    }
    elsif ( $header =~ /\t/ ) {
        $split_char = "\t";
    }
    else {
        $self->error_message('Could not determine split character in sample map file from line: '.$header);
        return;
    }

    my @samples;
    while ( my $line = $fh->getline ) {
        my (undef, $name, $external_name) = split($split_char, $line);
        if ( not $name ) {
            $self->error_message('No sample name found in line: '.$line);
            return;
        }
        if ( not $external_name ) {
            $self->error_message('No external name found in line: '.$line);
            return;
        }
        next if $this_sample_should_be_excluded->($name);
        my $sample = Genome::Sample->get(name => $name);
        if ( not $sample ) {
            $self->error_message('Cannot get sample for name: '.$name);
            return;
        }
        push @samples, {
            sample => $sample,
            external_name => $external_name,
        };
    }
    $fh->close;

    if ( not @samples ) {
        $self->error_message("Found none or excluded all samples");
        return;
    }

    $self->status_message('Resolve samples and genotype files...OK');

    return @samples;
}

sub _import_samples {
    my ($self, @samples) = @_;

    Carp::confess('No samples given to import samples') if not @samples;

    $self->status_message('Import genotype file for samples');

    my @models;
    for my $sample ( @samples ) {
        $self->status_message('Sample: '.$sample->{sample}->name);
        my $genotype_file = $sample->{genotype_file};
        $self->status_message('Genotype file: '.$genotype_file);
        if ( not -s $genotype_file ) {
            $self->error_message('No genotype file for sample: '.Dumper($sample));
            return;
        }
        my $import = Genome::InstrumentData::Command::Import::Microarray::GenotypeFile->create(
            sample => $sample->{sample},
            original_data_path => $self->original_data_path,
            reference_sequence_build => $self->reference_sequence_build,
            sequencing_platform => 'illumina',
            genotype_file => $genotype_file,
            description => $self->description,
            import_source_name => $self->import_source_name,
        );
        if ( not $import ) {
            $self->error_message('Failed to create genotype file importer');
            return;
        }
        $import->dump_status_messages(1);
        if ( not $import->execute ) {
            $self->error_message('Failed to execute genotype file importer');
            return;
        }
        push @models, $import->_model;
    }
    $self->_models(\@models);

    $self->status_message('Import genotype file for samples...OK');

    return 1;
}

1;

