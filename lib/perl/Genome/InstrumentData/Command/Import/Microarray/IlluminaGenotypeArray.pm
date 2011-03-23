package Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArray;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Copy::Recursive;
use File::Basename;
use IO::Handle;

class Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArray {
    is  => 'Genome::InstrumentData::Command::Import::Microarray',
    doc => 'create an instrument data for a microarray',
};


sub process_imported_files {

    my $self = shift;
    $self->sequencing_platform("illumina genotype array");
    $self->SUPER::process_imported_files(@_);
    my $instrument_data = Genome::InstrumentData::Imported->get( sample_name => $self->sample_name, sequencing_platform => $self->sequencing_platform);
    my $disk_alloc;# = $self->allocation;
    if($instrument_data) {
        $disk_alloc = $instrument_data->disk_allocations;
    }
    unless($disk_alloc) {
        $self->error_message("could not retrieve disk allocation");
        die $self->error_message;
    }

    my $genome_sample = Genome::Sample->get(name => $self->sample_name);


    my $path = $disk_alloc->absolute_path;
    my $genotype_path = $disk_alloc->absolute_path;

    unless (-d $genotype_path) {
        print "No genotype folder was found, attempting to generate one\n";
        
        unless(mkdir $genotype_path) {
            $self->error_message("Unable to create path for genotype file.");
            die $self->error_message;
        }
    }

    
    #find illumina manifest and call files among the imported data
    opendir(DIR,$path);
    my @files = readdir(DIR);

    my $genotype_path_and_file;
    my $processing_profile;

    my $call_file;
    my $illumina_manifest;

    for my $file (@files) {
        #print $file."\n";
        if(-d "$path/$file") {
            next;
        } elsif (-b "$path/$file") {
            next;
        } else {
            my $fh = new IO::File "$path/$file","r";
            #unless($fh->fdopen( "$path/$file","r")) {
            unless(defined($fh)) {
                print "could not open ".$file.". Skipping this file.\n";
                next;
            }
            my $count = 0;

            #test to see if files for illumina genotype array are present
            my $match;
            while ($count < 10) {
                my $line = $fh->getline; 
                unless(defined($line)) {
                    last;
                }
                if ($line =~ /Assay/) {
                    $match = $&;
                    last;
                }
                if ($line =~ /Data/) {
                    $match = $&;
                    last;
                }
                $count++;
            }
            $fh->close;
            if (defined($match)) {
                if ($match eq "Assay") {
                    $illumina_manifest = $path."/".$file;
                } elsif ($match eq "Data") {
                    $call_file = $path."/".$file;
                }
            }
            if ((defined($illumina_manifest)) and (defined($call_file))) {
                #files are present, deciding this is an illumina genotype array
                print "Input files determined to be Illumina Genotype Array.\n";
                print "call_file = ".$call_file."\n";
                print "illumina_manifest = ".$illumina_manifest."\n";
                $genotype_path_and_file = $genotype_path."/".$genome_sample->name.".genotype";
                $processing_profile = "illumina/wugc";
                last;
            }
        }
    }

    unless(defined($genotype_path_and_file)) {
        $genotype_path_and_file = $genotype_path."/".$genome_sample->name.".genotype";
    }

    unless(defined($processing_profile)) {
        $processing_profile = "illumina/wugc";
    }

    unless (-s $genotype_path_and_file) {

        print "genotype file not found, attempting to generate one.\n";

        unless (Genome::Model::Tools::Array::CreateGenotypesFromIlluminaCalls->execute(  
                                            sample_name     =>  $genome_sample->name,
                                            call_file       =>  $call_file,
                                            illumina_manifest_file  =>  $illumina_manifest,
                                            output_path     =>  $genotype_path, )) {
            $self->error_message("Call to CreateGenotypesFromIlluminaCalls failed.");
            die $self->error_message;
        }
        print "Created genotype file at ".$genotype_path_and_file."\n";
    }

    #create SNP Array Genotype (goldSNP)
    my $genotype_path_and_SNP = $genotype_path."/".$genome_sample->name."_SNPArray.genotype";
    my $reference_fasta_file = $self->reference_sequence_build->full_consensus_path('fa');
    unless(Genome::Model::Tools::Array::CreateGoldSnpFromGenotypes->execute(    genotype_file1 => $genotype_path_and_file,
                                                                                genotype_file2 => $genotype_path_and_file,
                                                                                output_file    => $genotype_path_and_SNP,
                                                                                reference_fasta_file => $reference_fasta_file, )) {
        $self->error_message("SNP Array Genotype creation failed");
        die $self->error_message;
    }

    $disk_alloc->reallocate;
    
    #create genotype model

    unless(Genome::Model::Command::Define::GenotypeMicroarray->execute(     file                        =>  $genotype_path_and_SNP,
                                                                            processing_profile_name     =>  $processing_profile,
                                                                            subject_name                =>  $genome_sample->name,
                                                                            reference                   =>  $self->reference_sequence_build,
            )) {
        $self->error_message("GenotpeMicroarray Model Define failed.");
        die $self->error_message;
    }


    return 1;
}


1;

    


    

