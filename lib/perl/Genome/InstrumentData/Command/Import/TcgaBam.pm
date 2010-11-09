package Genome::InstrumentData::Command::Import::TcgaBam;

use strict;
use warnings;

use Genome;
use File::Copy;
#use GSCApp;

my %properties = (
    original_data_path => {
        is => 'Text',
        doc => 'original data path of import data file',
    },
    tcga_name => {
        is => 'Text',
        doc => 'TCGA name for imported file',
    },
    remove_original_bam => {
        is => 'Boolean',
        doc => 'By uncluding this in your command, the tool will remove (delete!) the original bam file after importation, without warning.',
        default => 0,
        is_optional => 1,
    },
    no_md5 => {
        is => 'Boolean',
        default => 0,
        is_optional => 1,
    },
    create_sample => {
        is => 'Boolean',
        doc => 'Set this switch to automatically create organism_sample, library, and individual, if they are not not found.',
        default => 0,
        is_optional => 1,
    },
    import_source_name => {
        is => 'Text',
        doc => 'source name for imported file, like broad',
        is_optional => 1,
    },
    species_name => {
        is => 'Text',
        doc => 'species name for imported file, like human, mouse',
        default => 'human',
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
    

class Genome::InstrumentData::Command::Import::TcgaBam {
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
    my $self = shift;
    my $bam_path = $self->original_data_path;

    my $tcga_name = $self->tcga_name;
    unless(defined($self->import_source_name)){
        my (undef,$source) = split "-", $tcga_name;
        $self->import_source_name($source);
    }

    my $organism_sample = GSC::Organism::Sample->get(sample_name => $tcga_name);

    my $sample;
    unless($organism_sample){
        $self->status_message("Did not find an organism_sample associated with this TCGA name.");
        unless(defined($self->create_sample)&& $self->create_sample == 1){
            $self->error_message("Since --create-sample was not set, this process is dead.\n");
            die $self->error_message;
        }
        unless(defined($self->species_name)){
            $self->error_message("If an organism_sample is to be created, a species_name is required.");
            die $self->error_message;
        }
        my ($first, $second, $third) = split "-", $tcga_name;
        my $individual_name = join "-", ($first,$second,$third);
        unless( Genome::Sample::Command::Import->execute(sample_name => $tcga_name, individual_name => $individual_name, taxon_name => $self->species_name)){
            $self->error_message("Sample Importation failed.");
            die $self->error_message;
        }
    }
    $sample = Genome::Sample->get(name=>$tcga_name);
    unless($sample){
        $self->error_message("Found an organism_sample for ".$tcga_name." but could not get a Genome::Sample.");
        die $self->error_message;
    }
    $self->status_message("Found an organism_sample associate with this TCGA name.");
    my $library = Genome::Library->get(sample_id => $sample->id);
    unless($library){
        $self->status_message("Not able to find a library associated with this sample. If create_sample was set, it failed to create an appropriate library.");
        die "We don't currently allow for creating libraries.\n";
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
        next if $property_name =~ /tcga/;
        next if $property_name =~ /^create_sample$/;
        $params{$property_name} = $self->$property_name if $self->$property_name;
    }
    $params{sample_id} = $sample->id;
    $params{sample_name} = $sample->name;
    $params{sequencing_platform} = "solexa";
    $params{import_format} = "bam";
    $params{reference_sequence_build_id} = $self->reference_sequence_build_id;
    $params{library_id} = $library->id;
    unless(exists($params{description})){
        $params{description} = "imported ".$self->import_source_name." bam, tcga name is ".$tcga_name;
    }
    if($self->no_md5){
        $params{description} = $params{description} . ", no md5 file was provided with the import.";
    }
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

    #check for existing md5 sum
    my $md5_from_file;
    unless($self->no_md5){
        if(-s $bam_path . ".md5"){
            $self->status_message("Found an md5 sum, comparing it with the calculated sum...");
            my $md5_fh = IO::File->new($bam_path . ".md5");
            unless($md5_fh){
                $self->error_message("Could not open md5sum file.");
                die $self->error_message;
            }
            $md5_from_file = $md5_fh->getline;
            ($md5_from_file) = split " ", $md5_from_file;
            chomp $md5_from_file;
        } else {
            $self->status_message("Not able to locate a pre-calculated md5 sum at ".$bam_path.".md5");
            die $self->error_message;
        }
    }
    $self->status_message("Now calculating the MD5sum of the bam file to be imported, this will take a long time (many minutes) for larger (many GB) files.");
    my $md5 = Genome::Utility::FileSystem->md5sum($bam_path);
    unless($md5){
        $self->error_message("Failed to calculate md5 sum, exiting import command.");
        die $self->error_message;
    }
    $self->status_message("Finished calculating md5 sum.");
    $self->status_message("MD5 sum = ".$md5);

    $self->status_message("md5 sum from file = ".$md5_from_file);
    unless($md5 eq $md5_from_file){
        $self->error_message("Calculated md5 sum and sum read from file did not match, aborting.");
        $disk_alloc->deallocate;
        $self->error_message("Now removing instrument-data record from the database.");
        $import_instrument_data->delete;
        die "Import Failed";
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

    unless(Genome::Utility::FileSystem->md5sum($bam_destination) eq $md5) {
        $self->error_message("Failed to copy to allocated space (md5 mismatch).  Unlinking and deallocating.");
        unlink($bam_destination);
        $disk_alloc->deallocate;
        $self->error_message("Now removing instrument-data record from the database.");
        $import_instrument_data->delete;
        die "Import Failed.";
    }

    $self->status_message("Importation of BAM completed successfully.");
    $self->status_message("Your instrument-data id is ".$instrument_data_id);
    if($self->remove_original_bam){
        $self->status_message("Now removing original bam in 10 seconds.");
        for (1..10){
            sleep 1;
            print "slept for ".$_." seconds.\n";
        }
        unless(-s $bam_path){
            $self->error_message("Could not locate file to remove at ".$bam_path."\n");
            die $self->error_message;
        }
        unlink($bam_path);
        if(-s $bam_path){
            $self->error_message("Could not remove file at ".$bam_path."\n");
            $self->error_message("Check file permissions.");
        }else{
            $self->status_message("Original bam file has been removed from ".$bam_path);
        }
    }

    return 1;
}

1;
