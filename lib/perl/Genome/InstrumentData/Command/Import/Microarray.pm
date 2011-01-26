package Genome::InstrumentData::Command::Import::Microarray;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Path;
use File::Copy::Recursive;
use File::Basename;
use IO::Handle;

my %properties = (
    original_data_path => {
        is => 'Text',
        doc => 'original data path of import data file(s): all files in path will be used as input',
        is_optional => 1,
    },
    original_data_files => {
        is => 'Text',
        doc => 'original data file(s). If multiple, delimit with commas. Use this OR original_data_path but NOT both.',
        is_optional => 1,
    },
    sample_name => {
        is => 'Text',
        doc => 'sample name for imported file, like TCGA-06-0188-10B-01D',
    },
    library_name => {
        is => 'Text',
        doc => 'library name for imported file, like TCGA-06-0188-10B-01D-microarraylib',
        is_optional => 1,
    },
    import_source_name => {
        is => 'Text',
        doc => 'source name for imported file, like Broad Institute',
        is_optional => 1,
    },
    import_format => {
        is => 'Text',
        doc => 'format of import data, like microarray',
        valid_values => ['unknown'],                
        is_optional => 1,
    },
    sequencing_platform => {
        is => 'Text',
        doc => 'sequencing platform of import data, like illumina/affymetrix',
        valid_values => ['illumina genotype array', 'illumina expression array', 'affymetrix genotype array', '454','sanger', 'illumina methylation array', 'nimblegen methylation array','unknown'],
        is_optional => 1,
    },
    description  => {
        is => 'Text',
        doc => 'general description of import data, like which software maq/bwa/bowtie to used to generate this data',
        is_optional => 1,
    },
    allocation => {
        is => 'Genome::Disk::Allocation',
        is_optional => 1,
        #reverse_as => 'owner', where => [ allocation_path => {operator => 'like', value => '%imported%'} ], is_optional => 1, is_many => 1, 
        doc => 'For testing purposes',

    },
    species_name => {
        is => 'Text',
        doc => 'this is only needed if the sample being used is not already in the database.',
        is_optional => 1,
    },
    reference_sequence_build => {
        is => 'Genome::Model::Build::ImportedReferenceSequence',
        id_by => 'reference_sequence_build_id',
        doc => 'Build of the reference against which the genotype file was produced.',
        is_optional => 0,
    },
    reference_sequence_build_id  => {
        is => 'Number',
        doc => 'Build-id of the reference against which the genotype file was produced.',
        is_optional => 0,
    },
    _library => {
        is=> 'Genome::Library',
        is_transient => 1,
        is_optional => 1,
    }
);
    
class Genome::InstrumentData::Command::Import::Microarray {
    is => 'Genome::Command::Base',
    is_abstract => 1,
    has => [%properties],
    doc => 'import external microarray instrument data',
};

sub execute {
    my $self = shift;
    $self->process_imported_files;
}

sub process_imported_files {
    my ($self,$sample_name) = @_;
    unless(defined($self->original_data_files)||defined($self->original_data_path)){
        $self->error_message("Neither original_data_files nor original_data_path was defined. One of these is required to proceed.");
        die $self->error_message;
    }
    if(defined($self->original_data_path)){
        unless ((-s $self->original_data_path)||(-d $self->original_data_path)) {
            $self->error_message('Original data path to be imported: '. $self->original_data_path .' is empty or is not a directory');
            return;
        }
    } else {
        my @files = split ",",$self->original_data_files;
        for my $file (@files){
            unless(-s $file){
                $self->error_message("The file ".$file." had zero size or did not exist.");
                die $self->error_message;
            }
        }
    }
    my %params = ();
    for my $property_name (keys %properties) {
        unless ($properties{$property_name}->{is_optional}) {
            unless ($self->$property_name) {
                $self->error_message ("Required property: $property_name is not given");
                return;
            }
        }
        next if $property_name =~ /^(species|reference)_name$/;
        next if $property_name eq "allocation";
        next if $property_name eq "original_data_files";
        next if $property_name eq "_library";
        next if $property_name eq "library_name";
        next if $property_name eq "sample_name";
        $params{$property_name} = $self->$property_name if defined($self->$property_name);
    }

    $sample_name = $self->sample_name;
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
        $self->error_message("Could not find sample by the name of: ".$sample_name.". To continue, add the sample and rerun.");
        die $self->error_message;
    }

    my $library;
    if ($self->library_name) {
        unless ($library = Genome::Library->get(name=>$self->library_name)) {
            $self->error_message("Can't find library by name of " . $self->library_name . " To continue please give a correct library name"); 
        }
    } else {
        unless ($library = Genome::Library->get(name=>$genome_sample->name."-microarraylib")) {
            $library = Genome::Library->create(name=>$genome_sample->name . "-microarraylib", sample=>$genome_sample);
        }
        unless ($library) {
            $self->error_message("Can't find library by name of " . $genome_sample->name. "-microarraylib and can't create one either.");
            die $self->error_message;
        }
    }
    $self->_library($library);
    $params{library_id} = $library->id;
    
    my $sample_id = $genome_sample->id;
    $self->status_message("genome sample $sample_name has id: $sample_id");
    $params{import_format} = "unknown";
    if($self->allocation) {
        $params{disk_allocations} = $self->allocation;
    }
    if(defined($self->original_data_files)){
        $params{original_data_path} = $self->original_data_files;
    }
    my $import_instrument_data = Genome::InstrumentData::Imported->create(%params); 

    unless ($import_instrument_data) {
       $self->error_message('Failed to create imported instrument data for '.$self->original_data_path);
       return;
    }

    my $instrument_data_id = $import_instrument_data->id;
    $self->status_message("Instrument data record $instrument_data_id has been created.");
    print "Intrument data:".$instrument_data_id." is imported.\n";

    #Copying a minimum of 2x original file size into this allocation, after this finishes.
    my $kb_usage = $import_instrument_data->calculate_alignment_estimated_kb_usage *4;

    my $alloc_path = sprintf('microarray_data/imported/%s', $instrument_data_id);

    my %alloc_params = (
        disk_group_name     => 'info_alignments',
        allocation_path     => $alloc_path,
        kilobytes_requested => $kb_usage,
        owner_class_name    => $import_instrument_data->class,
        owner_id            => $import_instrument_data->id,
    );

    my $disk_alloc = $import_instrument_data->disk_allocations;

    unless($disk_alloc) {
        print "Allocating disk space\n";
        $self->status_message("Allocating disk space");
        $disk_alloc = Genome::Disk::Allocation->allocate(%alloc_params); 
    }
    unless ($disk_alloc) {
        $self->error_message("Failed to get disk allocation with params:\n". Data::Dumper::Dumper(%alloc_params));
        die $self->error_message;
    }
    $self->status_message("Microarray allocation created for $instrument_data_id.");

    my $target_path = $disk_alloc->absolute_path;# . "/";
    $self->status_message("Microarray allocation created at $target_path .");
    print "attempting to copy data to allocation\n";
    if(defined($self->original_data_path)){
        local $File::Copy::Recursive::KeepMode = 0;
        my $status = File::Copy::Recursive::dircopy($self->original_data_path,$target_path);
        unless($status) {
            $self->error_message("Directory copy failed to complete.\n");
            return;
        }

        my $ssize = Genome::Sys->directory_size_recursive($self->original_data_path);             
        my $dsize = Genome::Sys->directory_size_recursive($target_path);             
        unless ($ssize==$dsize) {
            unless($import_instrument_data->id < 0) {
                $self->error_message("source and distination do not match( source $ssize bytes vs destination $dsize). Copy failed.");
                $self->status_messsage("Removing failed copy");
                print $self->status_message."\n";
                rmtree($target_path);
                $disk_alloc->deallocate;
                return;
            }
        }
    } else {
        my $suff = ".txt";
        my @files = split ",",$self->original_data_files;
        for my $file (@files){
            my ($filename,$path,$suffix) = fileparse($file,$suff);
            my $target = $target_path . "/" . $filename . $suffix;
            if(-s $target){
                $self->error_message("A copy of the file at ".$target." already exists.");
                die $self->error_message;
            }
            my $status = Genome::Sys->copy_file($file, $target);
        }
    }
    $self->status_message("Finished copying data into the allocated disk");
    print "Finished copying data into the allocated disk.\n";

    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/InstrumentData/Command/Import.pm $
#$Id: Import.pm 53285 2009-11-20 21:28:55Z fdu $
