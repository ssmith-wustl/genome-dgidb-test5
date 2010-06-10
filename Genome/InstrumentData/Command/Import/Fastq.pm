package Genome::InstrumentData::Command::Import::Fastq;

#REVIEW fdu
#Long: need more specific external bam info like patient source, and add
#methods to calculate read/base count

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Basename;
use Data::Dumper;

my %properties = (
    source_data_files => {
        is => 'Text',
        doc => 'source data path of import data file',
    },
    library_name => {
        is => 'Text',
        doc => 'library name, used to fetch sample name',
    },
    sample_name => {
        is => 'Text',
        doc => 'sample name for imported file, like TCGA-06-0188-10B-01D',
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
        valid_values => ['fastq'],
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
    reference_name  => {
        is => 'Text',
        doc => 'reference name for imported data aligned against, if this is given, an alignment allocaiton will be created',
        is_optional => 1,
    },
    allocation => {
        is => 'Genome::Disk::Allocation',
        is_optional => 1,
    },
    read_length => {
        is => 'Number',
        doc => '------',
        is_optional => 1,
    },
    fwd_read_length => {
        is => 'Number',
        doc => '------',
        is_optional => 1,
    },
    rev_read_length => {
        is => 'Number',
        doc => '------',
        is_optional => 1,
    },
    fragment_count => {
        is => 'Number',
        doc => '------',
        is_optional => 1,
    },
    run_name => {
        is => 'Text',
        doc => '------',
        is_optional => 1,
    },
    subset_name => {
        is => 'Text',
        doc => '------',
        is_optional => 1,
    },
    sd_above_insert_size => {
        is => 'Number',
        doc => '------',
        is_optional => 1,
    },
    median_insert_size => {
        is => 'Number',
        doc => '------',
        is_optional => 1,
    },
    is_paired_end => {
        is => 'Number',
        doc => '------',
        is_optional => 1,
    },
);
    

class Genome::InstrumentData::Command::Import::Fastq {
    is  => 'Command',
    has => [%properties],
};


sub execute {
    my $self = shift;

$DB::single = 1;

    #TODO put logic to set sample_name and library_name
    my $library = Genome::Library->get(name => $self->library_name);
    unless ($library) {
        $self->error_message("Library name not found.");
        die $self->error_message;
    }
    
    my $genome_sample = Genome::Sample->get(id => $library->sample_id);
    unless ($genome_sample) {
        $self->error_message("Could not retrieve sample from library name");
        die $self->error_message;
    }
    my $sample_name  = $genome_sample->name; #$self->sample_name;
    if ($genome_sample) {
        $self->status_message("Sample with full_name: $sample_name is found in database");
    }
    else {
        $genome_sample = Genome::Sample->get(extraction_label => $sample_name);
        $self->status_message("Sample with sample_name: $sample_name is found in database")
            if $genome_sample;
    }

    unless ($genome_sample) {
        $self->error_message("Sample $sample_name is not found in database");
        die $self->error_message;
    }
    my $sample_id = $genome_sample->id;
    $self->status_message("genome sample $sample_name has id: $sample_id");
    $self->sample_name($genome_sample->name);
   
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
        next if $property_name =~ /^source_data_files$/;
        next if $property_name =~ /^allocation$/;
        next if $property_name =~ /^library_name$/;
        $params{$property_name} = $self->$property_name if $self->$property_name;
    }

    $params{sequencing_platform} = "solexa";
    $params{import_format} = "fastq";
    $params{sample_id} = $sample_id;
    $params{library_id} = $library->id;
    $params{library_name} = $library->name;
    if(defined($self->allocation)){
        $params{disk_allocations} = $self->allocation;
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

    my $ref_name = $self->reference_name;

    my $sources = $self->source_data_files;

    if( $sources =~ s/\/\//\//g) {
        $self->source_data_files($sources);            
        print "new source = ".$self->source_data_files."\n";
    }

    my @input_files = split /\,/, $self->source_data_files;
    foreach (sort(@input_files)) {
        unless( -s $_) {
            $self->error_message("Input file(s) were not found $_");
            die $self->error_message;
        }
    }        
    $self->source_data_files(join( ',',sort(@input_files)));
    print "source data files = ".$self->source_data_files."\n";
    my $tmp_tar_file = File::Temp->new("fastq-archive-XXXX",DIR=>"/tmp");
    my $tmp_tar_filename = $tmp_tar_file->filename;

    my @suffixes = (".txt",".fastq");    
    my $basename;
    my %basenames;
    my @inputs;
    for my $file (sort(@input_files)) {
        my ($filename,$path,$suffix) = fileparse($file, @suffixes);
        $basenames{$path}++;
        $basename = $path;
        push @inputs,$filename.$suffix;
    }
    unless(scalar(keys(%basenames))==1) {
        $self->error_message("Found more than one path to imported files.");
        die $self->error_message;
    }
    my $tar_cmd = sprintf("tar cvzf %s -C %s %s",$tmp_tar_filename,$basename, join " ", @inputs);
    print $tar_cmd, "\n";
    system($tar_cmd);

    $import_instrument_data->original_data_path($self->source_data_files);

    my $kb_usage = $import_instrument_data->calculate_alignment_estimated_kb_usage;

    unless ($kb_usage) {
        $self->warning_message('Failed to get estimate kb usage for instrument data '.$instrument_data_id);
        return 1;
    }

    my $alloc_path = sprintf('instrument_data/imported/%s', $instrument_data_id);

    
    my %alloc_params = (
        disk_group_name     => 'info_alignments',     #'info_apipe',          #changed to info_alignments disk due to problems with info_apipe
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
    $self->status_message("Disk allocation created for $instrument_data_id ." . $disk_alloc->absolute_path);
    
    my $real_filename = sprintf("%s/archive.tgz", $disk_alloc->absolute_path);

    my $md5 = Genome::Utility::FileSystem->md5sum($tmp_tar_filename);
    unless(copy($tmp_tar_filename, $real_filename)) {
        $self->error_message("Failed to copy to allocated space (copy returned bad value).  Unlinking and deallocating.");
        unlink($real_filename);
        $disk_alloc->deallocate;
        return;
    }
    
    unless(Genome::Utility::FileSystem->md5sum($real_filename) eq $md5) {
        $self->error_message("Failed to copy to allocated space (md5 mismatch).  Unlinking and deallocating.");
        unlink($real_filename);
        $disk_alloc->deallocate;
        return;
    }

    return 1;

}

1;

    


    

