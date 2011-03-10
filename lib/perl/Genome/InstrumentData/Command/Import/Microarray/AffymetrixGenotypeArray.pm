package Genome::InstrumentData::Command::Import::Microarray::AffymetrixGenotypeArray;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Copy::Recursive;
use File::Basename;
use IO::Handle;

class Genome::InstrumentData::Command::Import::Microarray::AffymetrixGenotypeArray {
    is  => 'Genome::InstrumentData::Command::Import::Microarray',
    doc => 'create an instrument data for a microarray',
    has => [
        annotation_file => {
            is => 'Text',
            doc => 'The absolute path to the Affy annotation file. If unspecified, the importer will try to determine which is best based on sample_name.',
            is_optional => 1,
        },
    ],
};


sub process_imported_files {
    my $self = shift;
    #die unless $self->allocation;
    $self->sequencing_platform('affymetrix genotype array');
    $self->SUPER::process_imported_files(@_);
    my @instrument_data = Genome::InstrumentData::Imported->get( sample_name => $self->sample_name, sequencing_platform => $self->sequencing_platform);
    unless(scalar(@instrument_data)==1){
        $self->error_message("Found ".scalar(@instrument_data)." imported instrument data records with the sample name of ".$self->sample_name." and sequencing-platform of ".$self->sequencing_platform);
        die $self->error_message;
    }
    my $instrument_data = $instrument_data[0];
    my $disk_alloc = $self->allocation;

    unless(defined($self->annotation_file)){
        my $annotation_file;
        if($self->sample_name =~ /^(H_LS|H_LR)/){
            $annotation_file = "/gscmnt/sata160/info/medseq/tcga/GenomeWideSNP_6.na31.annot.csv";
            $self->status_message("H_LS or H_LR project detected, using annotation file with build37 coordinates.");
        } else {
            $annotation_file = "/gscmnt/sata160/info/medseq/tcga/GenomeWideSNP_6.na28.annot.csv";
            $self->status_message("Using annotation file with build36 coordinates.");
        }
        unless(-s $annotation_file){
            $self->error_message("Cannot find installed annotation file at " . $annotation_file);
            die $self->error_message;
        }
        $self->annotation_file($annotation_file);
    }
    unless(-s $self->annotation_file){
        $self->error_message("Could not find annotation_file at ".$self->annotation_file);
        die $self->error_message;
    }

    if($instrument_data) {
        $disk_alloc = $instrument_data->disk_allocations;
    } else {
        $self->error_message("Could not retreive instrument data.");
        die $self->error_message;
    }
    unless($disk_alloc) {
        $self->error_message("could not retrieve disk allocation");
        die $self->error_message;
    }

    my $genome_sample = Genome::Sample->get(name => $self->sample_name);

    # If an allocation is passed in, use it
    my $genotype_path = (defined($self->allocation))? $self->allocation->absolute_path: $disk_alloc->absolute_path;

    unless (-d $genotype_path) {
        $self->error_message( "Unable to find allocation path\n");
        die $self->error_message;
    }

    my @files = glob( $genotype_path."/*" );
    my $call_file;
    if(@files > 1) {
        for (@files) {
            unless( $_ =~ /250(k|K)/ ) {
                $self->error_message("found multiple files, but one was not 250K type.");
                die $self->error_message;
            }
            
        }
        $call_file = "$genotype_path/cat_call_file.txt";
        for (@files) {
            system("cat ".$_." >>".$call_file);
        }
    } else {
        $call_file = $files[0];
    }


    my $genotype_path_and_file = $genotype_path."/".$genome_sample->name.".genotype";

    my $processing_profile = "affymetrix/wugc";

    unless (-s $genotype_path_and_file) {

        print "genotype file not found, attempting to generate one.\n";

        unless (Genome::Model::Tools::Array::CreateGenotypesFromAffyCalls->execute(  
                                            call_file       =>  $call_file,
                                            annotation_file  =>  $self->annotation_file,
                                            output_filename     =>  $genotype_path_and_file, )) {
            $self->error_message("Call to CreateGenotypesFromIlluminaCalls failed.");
            die $self->error_message;
        }
        $self->status_message( "Created genotype file at ".$genotype_path_and_file."\n");
        print $self->status_message."\n";
    }
    $self->status_message("finished creating genotype file, importing genotype and defining model.");

    unless(defined($self->allocation)){
        unless(Genome::InstrumentData::Command::Import::Microarray::GenotypeFile->execute(
            source_data_file => $genotype_path_and_file,
            import_source_name => $self->import_source_name,
            sequencing_platform => $self->sequencing_platform,
            reference_sequence_build => $self->reference_sequence_build,
            library => $self->_library,
            description => "Genotype automatically generated by affymetrix importer",
            
            define_model => 1)){
            $self->error_message("The call to import a genotype file has failed.");
            die $self->error_message;
        }
    }
    return 1;
}

1;
