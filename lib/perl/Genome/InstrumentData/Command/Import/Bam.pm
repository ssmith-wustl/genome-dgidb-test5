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
    sample => {
        is => 'Text',
        doc => 'sample name or ID for imported file',
    },
    target_region => {
        is => 'Text',
        doc => 'Provide target region set name (capture) or "none" (whole genome or RNA/cDNA)',
    },
    library => {
        is => 'String',
        doc => 'The library name or id associated with the data to be imported.',
        is_optional => 1,
    },
    create_library => {
        is => 'Boolean',
        doc => 'If the library (specified by name in the library parameter) does not exist, create it.',
        default => 0,
        is_optional => 1,
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
    is  => 'Genome::InstrumentData::Command::Import',
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
    my $self = shift;

    # If the target region is set to whole genome, then we want the imported instrument data's
    # target_region_set_name column set to undef. Otherwise, we need to make sure the target region
    # name corresponds to only one Genome::FeatureList.
    my $target_region;
    unless ($self->target_region eq 'none') {
        if ($self->validate_target_region) {
            $target_region = $self->target_region;
        } else {
            $self->error_message("Invalid target region " . $self->target_region);
            die $self->error_message;
        }
    }

    my $bam_path = $self->original_data_path;
    my $sample = Genome::Command::Base->resolve_param_value_from_text($self->sample, 'Genome::Sample');
    unless($sample){
        $self->error_message("Unable to find the sample name based on the parameter: ".$self->sample);
        my $possible_name;
        if($self->sample =~ /TCGA/){
            print "got here.\n";
            $possible_name = GSC::Organism::Sample->get(sample_name => $self->sample);
            if($possible_name){
                $self->error_message("There is an organism_sample which matches the TCGA name, which has a full_name of ".$possible_name->full_name);
            }
        }
        die $self->error_message;
    }

    my $library;

    if ($self->library) {
        $library = Genome::Command::Base->resolve_param_value_from_text($self->library,'Genome::Library');
    }

    unless($library){
        unless($self->create_library){
            $self->error_message("A library was not resolved from the input string ".$self->library);
            die $self->error_message;
        }
        $library = Genome::Library->get(name=>$sample->name.'-extlibs',sample_id=>$sample->id);
        unless ($library) {
            $library = Genome::Library->create(name=>$sample->name.'-extlibs',sample_id=>$sample->id);
        }
        unless($library){
            $self->error_message("Unable to create a library.");
            die $self->error_message;
        }
        $self->status_message("Created a library named ".$library->name);
        print $self->status_message;
    }

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
        next if $property_name =~ /^library$/;
        next if $property_name =~/^sample$/;
        next if $property_name  eq 'create_library';
        next if $property_name eq 'target_region';
        $params{$property_name} = $self->$property_name if $self->$property_name;
    }
    $params{sequencing_platform} = "solexa";
    $params{import_format} = "bam";
    $params{reference_sequence_build_id} = $self->reference_sequence_build_id;
    $params{library_id} = $library->id;
    $params{target_region_set_name} = $target_region;
    
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
    my $md5 = Genome::Sys->md5sum($bam_path);
    unless($md5){
        $self->error_message("Failed to calculate md5 sum, exiting import command.");
        die $self->error_message;
    }
    $self->status_message("Finished calculating md5 sum.");
    $self->status_message("MD5 sum = ".$md5);

    #check for existing md5 sum

    if(-s $bam_path . ".md5"){
        $self->status_message("Found an md5 sum, comparing it with the calculated sum...");
        my $md5_fh = IO::File->new($bam_path . ".md5");
        unless($md5_fh){
            $self->error_message("Could not open md5sum file.");
            die $self->error_message;
        }
        my $md5_from_file = $md5_fh->getline;
        ($md5_from_file) = split " ", $md5_from_file;
        chomp $md5_from_file;
        #chomp $md5;
        $self->error_message("md5 sum from file = ".$md5_from_file);
        unless($md5 eq $md5_from_file){
            $self->status_message("calcmd5 = ".$md5." and file md5 = ".$md5_from_file);
            $self->error_message("Calculated md5 sum and sum read from file did not match, aborting.");
            $disk_alloc->deallocate;
            $self->error_message("Now removing instrument-data record from the database.");
            $import_instrument_data->delete;
            die "Import Failed";
        }
    }
    
    #copy the bam into the allocation
    
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
    
    #calculate and compare md5 sums

    unless(Genome::Sys->md5sum($bam_destination) eq $md5) {
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
