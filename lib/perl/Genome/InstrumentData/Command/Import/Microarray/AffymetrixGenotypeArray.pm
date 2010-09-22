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
    $self->sequencing_platform('affymetrix genotype array');
    $self->SUPER::process_imported_files(@_);
    my $instrument_data = Genome::InstrumentData::Imported->get( sample_name => $self->sample_name, sequencing_platform => $self->sequencing_platform);
    my $disk_alloc = $self->allocation;

    my $annotation_file = "/gscmnt/sata160/info/medseq/tcga/GenomeWideSNP_6.na28.annot.csv";

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

    my $path = $disk_alloc->absolute_path;
    my $genotype_path = $disk_alloc->absolute_path;

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
                                            annotation_file  =>  $annotation_file,
                                            output_filename     =>  $genotype_path_and_file, )) {
            $self->error_message("Call to CreateGenotypesFromIlluminaCalls failed.");
            die $self->error_message;
        }
        $self->status_message( "Created genotype file at ".$genotype_path_and_file."\n");
        print $self->status_message."\n";
    }

    #create SNP Array Genotype (goldSNP)
    my $genotype_path_and_SNP = $genotype_path."/".$genome_sample->name."_SNPArray.genotype";
    unless(Genome::Model::Tools::Array::CreateGoldSnpFromGenotypes->execute(    genotype_file1 => $genotype_path_and_file,
                                                                                genotype_file2 => $genotype_path_and_file,
                                                                                output_file    => $genotype_path_and_SNP,)) {
        $self->error_message("SNP Array Genotype creation failed");
        die $self->error_message;
    }
    $self->status_message("SNP Array Genotype  file created at ".$genotype_path_and_SNP."\n");
    print $self->status_message."\n";
    $disk_alloc->reallocate;
    
    #create genotype model

    #don't build during a test
    my $no_build;
    if($disk_alloc->owner_id < 0) {
        $no_build = 1;
    } else {
        $no_build = 0;
    }

    unless(Genome::Model::Command::Define::GenotypeMicroarray->execute(     file                        =>  $genotype_path_and_SNP,
                                                                            processing_profile_name     =>  $processing_profile,
                                                                            subject_name                =>  $genome_sample->name,
                                                                            no_build                    =>  $no_build,
            )) {
        $self->error_message("GenotpeMicroarray Model Define failed.");
        die $self->error_message;
    }

    return 1;
}


1;

    


    

