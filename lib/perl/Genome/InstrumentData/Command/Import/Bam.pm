package Genome::InstrumentData::Command::Import::Bam;

#REVIEW fdu
#Long: need more specific external bam info like patient source, and add
#methods to calculate read/base count

use strict;
use warnings;

use Genome;
use File::Copy;


my %properties = (
    original_data_path => {
        is => 'Text',
        doc => 'original data path of import data file',
    },
    sample_name => {
        is => 'Text',
        doc => 'sample name for imported file, like TCGA-06-0188-10B-01D',
    },
    import_source_name => {
        is => 'Text',
        doc => 'source name for imported file, like Broad Institute',
        is_optional => 1,
    },
    species_name => {
        is => 'Text',
        doc => 'species name for imported file, like human, mouse',
        is_optional => 1,
    },
    sequencing_platform => {
        is => 'Text',
        doc => 'sequencing platform of import data, like solexa',
        valid_values => ['solexa'],
        is_optional => 1,
    },
    import_format => {
        is => 'Text',
        doc => 'import format, should be bam',
        valid_values => ['bam'],
        is_optional =>1,
    },
    description  => {
        is => 'Text',
        doc => 'general description of import data, like which software maq/bwa/bowtie to used to generate this data',
        is_optional => 1,
    },
    read_count  => {
        is => 'Number',
        doc => 'total read count of import data',
        is_optional => 1,
    },
    base_count  => {
        is => 'Number',
        doc => 'total base count of import data',
        is_optional => 1,
    },
    reference_sequence_build_id => {
        is => 'Number',
        doc => 'This is the reference sequence that the imported BAM was aligned against.',
        is_optional => 1,
    },
);
    

class Genome::InstrumentData::Command::Import::Bam {
    is  => 'Command',
    has => [%properties],
    doc => 'create an instrument data AND and alignment for a BAM',
    has_optional => [
        import_instrument_data_id => {
            is  => 'Number',
            doc => 'output instrument data id after import',
        },
    ],
};


sub execute {
    my $self     = shift;
    my $bam_path = $self->original_data_path;
    
    unless (-s $bam_path and $bam_path =~ /\.bam$/) {
        $self->error_message('Original data path of import bam: '. $bam_path .' is either empty or not with .bam as name suffix');
        return;
    }

    my %params = (import_format => 'bam');

    for my $property_name (keys %properties) {
        unless ($properties{$property_name}->{is_optional}) {
            unless ($self->$property_name) {
                $self->error_message ("Required property: $property_name is not given");
                return;
            }
        }
        next if $property_name =~ /^(species|reference)_name$/;
        $params{$property_name} = $self->$property_name if $self->$property_name;
    }
    
    my $sample_name   = $self->sample_name;
    my $genome_sample = Genome::Sample->get(name => $sample_name);

    if ($genome_sample) {
        $self->status_message("Sample with full_name: $sample_name is found in database");
    }
    else {
        $genome_sample = Genome::Sample->get(extraction_label => $sample_name);
        $self->status_message("Sample with sample_name: $sample_name is found in database")
            if $genome_sample;
    }

    unless ($genome_sample) {
        $self->error_message("Could not locate Genome::Sample named :  " . $sample_name);
        die $self->error_message;
    }
    
    my $sample_id = $genome_sample->id;
    $self->status_message("genome sample $sample_name has id: $sample_id");
    $params{sample_id} = $sample_id;
    $params{sequencing_platform} = "solexa";
    $params{import_format} = "bam";
    $params{reference_sequence_build_id} = $self->reference_sequence_build_id;
    
    my $import_instrument_data = Genome::InstrumentData::Imported->create(%params);  
    unless ($import_instrument_data) {
       $self->error_message('Failed to create imported instrument data for '.$self->original_data_path);
       return;
    }

    my $instrument_data_id = $import_instrument_data->id;
    $self->status_message("Instrument data: $instrument_data_id is imported");
    $self->import_instrument_data_id($instrument_data_id);

    my $kb_usage = $import_instrument_data->calculate_alignment_estimated_kb_usage;
    unless ($kb_usage) {
        $self->warning_message('Failed to get estimate kb usage for instrument data '.$instrument_data_id);
        return 1;
    }

    my $alloc_path = sprintf('alignment_data/imported/%s', $instrument_data_id);

    my %alloc_params = (
        disk_group_name     => 'info_alignments',
        allocation_path     => $alloc_path,
        kilobytes_requested => $kb_usage,
        owner_class_name    => $import_instrument_data->class,
        owner_id            => $import_instrument_data->id,
    );

    my $disk_alloc = Genome::Disk::Allocation->allocate(%alloc_params);
    unless ($disk_alloc) {
        $self->error_message("Failed to get disk allocation with params:\n". Data::Dumper::Dumper(%alloc_params));
        return 1;
    }
    $self->status_message("Alignment allocation created for $instrument_data_id .");

    my $bam_destination = $disk_alloc->absolute_path . "/all_sequences.bam";
    $self->status_message("Now calculating the MD5sum of the bam file to be imported, this will take a long time (many minutes) for larger (many GB) files.");
    my $md5 = Genome::Utility::FileSystem->md5sum($bam_path);
    unless($md5){
        $self->error_message("Failed to calculate md5 sum, exiting import command.");
        die $self->error_message;
    }
    $self->status_message("Finished calculating md5 sum.");
    $self->status_message("MD5 sum = ".$md5);
    $self->status_message("Copying bam file into the allocation, this could take some time.");
    unless(copy($bam_path, $bam_destination)) {
        $self->error_message("Failed to copy to allocated space (copy returned bad value).  Unlinking and deallocating.");
        unlink($bam_destination);
        $disk_alloc->deallocate;
        $self->error_message("Now removing instrument-data record from the database.");
        $import_instrument_data->delete;
        die "Import Failed.";
    }
    $self->status_message("Bam successfully copied to allocation. Now calculating md5sum of the copied bam, to compare with pre-copy md5sum. Again, this could take some time.");
    unless(not Genome::Utility::FileSystem->md5sum($bam_destination) eq $md5) {
        $self->error_message("Failed to copy to allocated space (md5 mismatch).  Unlinking and deallocating.");
        unlink($bam_destination);
        $disk_alloc->deallocate;
        $self->error_message("Now removing instrument-data record from the database.");
        $import_instrument_data->delete;
        die "Import Failed.";
    }
    $self->status_message("Importation of BAM completed successfully.");
    $self->status_message("Your instrument-data id is ".$instrument_data_id);
    return 1;
}


1;

    


    

