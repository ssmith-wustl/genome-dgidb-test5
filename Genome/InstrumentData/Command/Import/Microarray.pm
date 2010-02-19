package Genome::InstrumentData::Command::Import::Microarray;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Copy::Recursive;
use File::Basename;
use File::Find;

my %properties = (
    original_data_path => {
        is => 'Text',
        doc => 'original data path of import data file(s): all files in path will be used as input',
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
    import_format => {
        is => 'Text',
        doc => 'format of import data, like microarray',
        valid_values => ['microarray'],                
        is_optional => 1,
    },
    sequencing_platform => {
        is => 'Text',
        doc => 'sequencing platform of import data, like illumina/affymetrix',
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
    },
    library_id => {
        is => 'Number',
        is_optional => 1,
    },
);
    

class Genome::InstrumentData::Command::Import::Microarray {
    is  => 'Command',
    has => [%properties],
    doc => 'create an instrument data for a microarray',
};


sub execute {
    my $self = shift;

    unless (-s $self->original_data_path) {
        $self->error_message('Original data path of import file: '. $self->original_data_path .' is empty');
        return;
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
        $params{$property_name} = $self->$property_name if defined($self->$property_name);
    }

    my $sample_name     = $self->sample_name;
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
        $self->status_message("Sample $sample_name is not found in database, now try to store it");
        
        my $species_name = $self->species_name;
        my $taxon;
        
        $taxon = GSC::Organism::Taxon->get(species_name => $species_name);
        unless ($taxon) {
            $self->error_message("Failed to get GSC::Organism::Taxon for sample $sample_name and species $species_name");
            die $self->error_message;
        }
        $self->status_message("Species_name: $species_name is stored in organism_taxon");
        
        #Need set full name so Genome::Sample can recognize:
        #Organism_sample full name => Genome Sample name => Genome Model subject_name
        
        my $full_name;
        if ($sample_name =~ /^TCGA\-/) {
            $full_name = $sample_name;
            $full_name =~ s/^TCGA/H_GP/;
            chop $full_name unless $full_name =~ /R$/;
        }
        else {
            $full_name = undef;
            #maybe it should die here.
        }

        my %create_params = (
            name             => $full_name,      # internal/LIMS DNA_NAME
            extraction_label => $sample_name,    # external name (biospecimen or TCGA-*)
            cell_type        => 'primary',
            taxon_id         => $taxon->taxon_id,
        );
       
        $genome_sample = Genome::Sample->create(%create_params);
       
        unless ($genome_sample){
            $self->error_message('Failed to create the genome sample : '.Genome::Sample->error_message);
            die $self->error_message;
        }
        $self->status_message("Succeed to create genome sample for $sample_name");
    }
    
    my $sample_id = $genome_sample->id;
    $self->status_message("genome sample $sample_name has id: $sample_id");
    $params{sample_id} = $sample_id;

    my $import_instrument_data = Genome::InstrumentData::Imported->create(%params); #change Bamed to Microarray - create the Microarray subclass  
    unless ($import_instrument_data) {
       $self->error_message('Failed to create imported instrument data for '.$self->original_data_path);
       return;
    }

    my $instrument_data_id = $import_instrument_data->id;
    $self->status_message("Instrument data: $instrument_data_id is imported");

    my $kb_usage = $import_instrument_data->calculate_alignment_estimated_kb_usage;

    my $alloc_path = sprintf('microarray_data/imported/%s', $instrument_data_id);

    my %alloc_params = (
        disk_group_name     => 'info_alignments',
        allocation_path     => $alloc_path,
        kilobytes_requested => $kb_usage,
        owner_class_name    => $import_instrument_data->class,
        owner_id            => $import_instrument_data->id,
    );

    my $disk_alloc;

    if($self->allocation) {
        $disk_alloc = $self->allocation;
    }else {
        $disk_alloc = Genome::Disk::Allocation->allocate(%alloc_params); 
    }

    unless ($disk_alloc) {
        $self->error_message("Failed to get disk allocation with params:\n". Data::Dumper::Dumper(%alloc_params));
        return;
    }
    $self->status_message("Microarray allocation created for $instrument_data_id .");

    my $target_path = $disk_alloc->absolute_path . "/";
    $self->status_message("Microarray allocation created at $target_path .");

    my $status = File::Copy::Recursive::dircopy($self->original_data_path,$target_path);
    unless($status) {
        $self->error_message("Directory copy failed to complete.\n");
        return;
    }

    my $ssize = 0;             
    my $dsize = 0;             
    find(sub { $ssize += -s if -f $_ }, $self->original_data_path);   #find sum of source file sizes
    find(sub { $dsize += -s if -f $_ }, $target_path);                #find sum of target file sizes
    unless ($ssize==$dsize) {
        $self->error_message("source and distination do not match( source $ssize bytes vs destination $dsize). Copy failed.");
        return;
    }

    return 1;
}


1;

    


    

