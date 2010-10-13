package Genome::InstrumentData::Command::Import::Genotype;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Basename;
use Data::Dumper;
use IO::File;

my %properties = (
    source_data_file => {
        is => 'Text',
        doc => 'source data path of import data file',
    },
    library_name => {
        is => 'Text',
        doc => 'Define this OR sample_name OR both if you like.',
        is_optional => 1,
    },
    sample_name => {
        is => 'Text',
        doc => 'Define this OR library_name OR both if you like.',
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
    import_format => {
        is => 'Text',
        doc => 'format of import data, like bam',
        valid_values => ['genotype file'],
        default_value => 'genotype file',
    },
    sequencing_platform => {
        is => 'Text',
        doc => 'sequencing platform of import data, like solexa',
        is_optional => 1,
    },
    description  => {
        is => 'Text',
        doc => 'general description of import data, like which software maq/bwa/bowtie to used to generate this data',
        is_optional => 1,
    },
    read_count => {
        is => 'Number',
        doc => 'The number of reads in the genotype file',
        is_optional => 1,
    },
    reference_build_id  => {
        is => 'Number',
        doc => 'Build-id of the reference against which the genotype file was produced.',
        is_optional => 1,
    },
    allocation => {
        is => 'Genome::Disk::Allocation',
        is_optional => 1,
    },
    generated_instrument_data_id=> {
        is=>'Number',
        doc => 'generated sample ID',
        is_optional => 1,
    },
    define_model => {
        is=>'Boolean',
        doc => 'Create a goldSNP file from the imported genotype and define/build a GenotypeMicroarray model.',
        default_value => 0,
        is_optional => 1,
    },
);
    

class Genome::InstrumentData::Command::Import::Genotype {
    is  => 'Command',
    has => [%properties],
};


sub execute {
    my $self = shift;

    unless(defined($self->sample_name) || defined($self->library_name)){
        $self->error_message("In order to import a genotype, a library-name or sample-name is required.");
        die $self->error_message;
    }
    my $sample;
    my $library;

    if(defined($self->sample_name) && defined($self->library_name)){
        $sample = Genome::Sample->get(name => $self->sample_name);
        $library = Genome::Library->get(name => $self->library_name);
        unless(defined($sample)){
            $self->error_message("Could not locate a sample by the name of ".$self->sample_name);
            die $self->error_message;
        }
        unless(defined($library)){
            $self->error_message("Could not locate a library by the name of ".$self->library_name);
            die $self->error_message;
        }
        unless($sample->name eq $library->sample_name){
            $self->error_message("The supplied sample-name ".$self->sample_name." and the supplied library ".$self->library_name." do not match.");
            die $self->error_message;
        }
    } elsif (defined($self->library_name)){
        $library = Genome::Library->get(name => $self->library_name);
        unless(defined($library)) {
            $self->error_message("Library name not found.");
            die $self->error_message;
        }
        $sample = Genome::Sample->get(id => $library->sample_id);
        unless (defined($sample)) {
            $self->error_message("Could not retrieve sample from library name");
            die $self->error_message;
        }
        $self->sample_name($sample->name);
    } elsif (defined($self->sample_name)){
        $sample = Genome::Sample->get(name=>$self->sample_name);
        unless(defined($sample)){
            $self->error_message("Could not locate sample with the name ".$self->sample_name);
            die $self->error_message;
        }
        ($library) = Genome::Library->get(sample_name => $sample->name);
        unless(defined($library)){
            $self->error_message("COuld not locate a library associated with the sample-name ".$sample->name);
            die $self->error_message;
        }
        $self->library_name($library->name);
    } else {
        $self->error_message("Failed to define a sample or library.");
        die $self->error_message;
    }
   
    # gather together params to create the imported instrument data object 
    my %params = ();
    for my $property_name (keys %properties) {
        unless ($properties{$property_name}->{is_optional}) {
            # required
            unless ($self->$property_name) {
                # null
                $self->error_message ("Required property: $property_name is not given");
                return;
            }
        }
        next if $property_name =~ /^(species|reference)_name$/;
        next if $property_name =~ /^source_data_file$/;
        next if $property_name =~ /^allocation$/;
        next if $property_name =~ /^library_name$/;
        next if $property_name =~ /^define_model$/;
        $params{$property_name} = $self->$property_name if $self->$property_name;
    }

    $params{sequencing_platform} = $self->sequencing_platform; 
    $params{import_format} = $self->import_format;
    $params{sample_id} = $sample->id;
    $params{library_id} = $library->id;
    $params{library_name} = $library->name;
    if(defined($self->allocation)){
        $params{disk_allocations} = $self->allocation;
    }


    unless(defined($params{read_count})){
        my $read_count = $self->get_read_count();
        unless(defined($read_count)){
            $self->error_message("No read count was specified and none could be calculated from the file.");
            die $self->error_message;
        }
        $self->read_count($read_count);
        $params{read_count} = $read_count;
    }

    my $import_instrument_data = Genome::InstrumentData::Imported->create(%params);  
    unless ($import_instrument_data) {
       $self->error_message('Failed to create imported instrument data for '.$self->original_data_path);
       return;
    }

    unless ($import_instrument_data->library_id) {
        $DB::single = 1;
        Carp::confess("No library on new instrument data?"); 
    }

    my $instrument_data_id = $import_instrument_data->id;
    $self->status_message("Instrument data record $instrument_data_id has been created.");
    $self->generated_instrument_data_id($instrument_data_id);

    $import_instrument_data->original_data_path($self->source_data_file);

    my $kb_usage = $import_instrument_data->calculate_alignment_estimated_kb_usage;

    unless ($kb_usage) {
        $self->warning_message('Failed to get estimate kb usage for instrument data '.$instrument_data_id);
        return 1;
    }

    my $alloc_path = sprintf('instrument_data/imported/%s', $instrument_data_id);

    
    my %alloc_params = (
        disk_group_name     => 'info_alignments',     #'info_apipe',
        allocation_path     => $alloc_path,
        kilobytes_requested => $kb_usage,
        owner_class_name    => $import_instrument_data->class,
        owner_id            => $import_instrument_data->id,
    );


    my $disk_alloc;


    if($self->allocation) {
        $disk_alloc = $self->allocation;
    } else {
        $disk_alloc = Genome::Disk::Allocation->allocate(%alloc_params);
    }
    unless ($disk_alloc) {
        $self->error_message("Failed to get disk allocation with params:\n". Data::Dumper::Dumper(%alloc_params));
        return 1;
    }
    $self->allocation($disk_alloc);
    $self->status_message("Disk allocation created for $instrument_data_id ." . $disk_alloc->absolute_path);
    
    $self->status_message("About to calculate the md5sum of the genotype.");
    my $md5 = Genome::Utility::FileSystem->md5sum($self->source_data_file);
    $self->status_message("Copying genotype the allocation.");
    my $real_filename = $disk_alloc->absolute_path ."/". $self->sample_name . ".genotype";
    unless(copy($self->source_data_file, $real_filename)) {
        $self->error_message("Failed to copy to allocated space (copy returned bad value).  Unlinking and deallocating.");
        unlink($real_filename);
        $disk_alloc->deallocate;
        return;
    }
    $self->status_message("About to calculate the md5sum of the genotype in its new habitat on the allocation.");
    my $copy_md5;
    unless($copy_md5 = Genome::Utility::FileSystem->md5sum($real_filename)){
        $self->error_message("Failed to calculate md5sum.");
        die $self->error_message;
    }
    unless($copy_md5 eq $md5) {
        $self->error_message("Failed to copy to allocated space (md5 mismatch).  Unlinking and deallocating.");
        unlink($real_filename);
        $disk_alloc->deallocate;
        return;
    }
    $self->status_message("The md5sum for the copied genotype file is: ".$copy_md5);
    $self->status_message("The instrument-data id of your new record is ".$instrument_data_id);
    if($self->define_model){
        $self->define_genotype_model;
    }
    return 1;

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

sub define_genotype_model {
    my $self = shift;
    my $model;
    my $processing_profile = "unknown/wugc";
    if($model = Genome::Model::GenotypeMicroarray->get(sample_name=>$self->sample_name)){
        $self->error_message("Warning: a GenotypeMicroarry model (id ".$model->genome_model_id.") has already been defined for this sample ( name = ".$self->sample_name.".");
        die $self->error_message;
    }
    my $genotype_path_and_file = $self->allocation->absolute_path . "/" . $self->sample_name . ".genotype";
    my $snp_array = $self->allocation->absolute_path . "/" . $self->sample_name . "_SNPArray.genotype";
    unless(-s $snp_array){
        $self->status_message("Now creating a SNPArray file. This may take some time.");
        unless(Genome::Model::Tools::Array::CreateGoldSnpFromGenotypes->execute(    
            genotype_file1 => $genotype_path_and_file,
            genotype_file2 => $genotype_path_and_file,
            output_file    => $snp_array,)) {

            $self->error_message("SNP Array Genotype creation failed");
            die $self->error_message;
        }
    }
    $self->status_message("SNPArray defined, now defining/building model.");
    my $no_build;
    if($self->generated_instrument_data_id < 0) {
        $no_build = 1;
    } else {
        $no_build = 0;
    }
    unless($model = Genome::Model::Command::Define::GenotypeMicroarray->execute(     
        file =>  $snp_array,
        processing_profile_name =>  $processing_profile,
        subject_name =>  $self->sample_name,
        no_build =>  $no_build,
                                                            )) {
        $self->error_message("GenotpeMicroarray Model Define failed.");
        die $self->error_message;
    }
    
}
    

1;
