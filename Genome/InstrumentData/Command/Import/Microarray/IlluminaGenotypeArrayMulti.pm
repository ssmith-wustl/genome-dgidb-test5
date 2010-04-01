package Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArrayMulti;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Copy::Recursive;
use File::Basename;
use File::Temp;
use IO::Handle;
use Data::Dumper;

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
        valid_values => ['unknown'],                
        is_optional => 1,
    },
    sequencing_platform => {
        is => 'Text',
        doc => 'sequencing platform of import data, like illumina/affymetrix',
        valid_values => ['illumina genotype array', 'illumina expression array', 'affymetrix genotype array', '454','sanger','unknown'],
    },
    description  => {
        is => 'Text',
        doc => 'general description of import data, like which software maq/bwa/bowtie to used to generate this data',
        is_optional => 1,
    },
    allocation => {
        is => 'Genome::Disk::Allocation',
        id_by => 'allocator_id',
        is_optional => 1,
    },
    result_model_ids => {
        is => 'Array',
        is_optional => 1,
    },
    ucsc_array_file => {
        is => 'Text',
        is_optional => 1,
    },
    exclude_common_names => {
        is => 'Text',
        is_optional => 1,
        doc => 'Common names (names like "BRC1"), delineated by commas, to be excluded from the import command.\n',
    },
    include_common_names => {
        is => 'Text',
        is_optional => 1,
        doc => 'Common names (names like "BRC1"), delineated by commas, to be included in the import command. All others will be excluded.\n',
    },
);
    
class Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArrayMulti {
    is => 'Command',
    has => [%properties],
    doc => 'import external microarray instrument data',
};

sub execute {
    my $self = shift;
    $self->process_imported_files;
    return 1;
}

sub process_imported_files {
    my $self = shift;

    my %excluded_names;
    my %included_names;

    my $genome_sample;
    my $genotype_path;
    my $genotype_path_and_file;
    my $processing_profile;
    my $call_file;
    my $genotype;
    my $illumina_manifest;
    my $forward_strand_report;
    my $sample_map;

    if(defined($self->exclude_common_names) and not defined($self->include_common_names)) {
        %excluded_names = map { $_ => 1} split( ',', $self->exclude_common_names);
    }
    if(defined($self->include_common_names) and not defined($self->exclude_common_names)) {
        %included_names = map { $_ => 1} split( ',', $self->include_common_names);
    }
    if(defined($self->include_common_names) and defined($self->exclude_common_names)) {
        $self->error_message("You may not simultaneously include and exclude common names.");
        die $self->error_message;
    }

    unless(defined($self->ucsc_array_file)) {
        $self->ucsc_array_file("/gscmnt/sata135/info/medseq/dlarson/snpArrayIllumina1M");
    }

    my $path = $self->original_data_path;
    opendir(DIR,$path);
    my @files = readdir(DIR);

    #read through the files in the provided source dir, 
    # looking for the sample mapping and the forwardread file.
    for my $file (@files) {
        if(-d "$path/$file") {
            next;
        } elsif (-b "$path/$file") {
            next;
        } else {
            my $fh = new IO::File "$path/$file","r";
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
                if ($line =~ /Data/) {
                    $match = $&;
                    last;
                }
                if ($line =~ /Index,Name,ID/) {
                    $match = $&;
                    last;
                }
                $count++;
            }
            $fh->close;
            if (defined($match)) {
                if ($match eq "Index,Name,ID") {
                    $sample_map = $file;
                    #last;
                } elsif ($match eq "Data") {
                    $genotype = $file;
                }
            }

            if (defined($genotype) and defined($sample_map)) {
                last;
            }
        }
    }


    my $sample_map_fh;
    unless($sample_map_fh = new IO::File "$path/$sample_map","r"){
        $self->error_message("Could not open file ".$path."/".$sample_map);
        die $self->error_message;
    }
    #my $throwaway = 
    $sample_map_fh->getline;
    my %names;
    my %normal;
    my %internal;

    #extract common_name from sample mapping
    while(my $line = $sample_map_fh->getline) {
        my ($index, $common_name,$internal, @junk) = split ',', $line;
        $common_name =~ s/(\s)//;
        $common_name =~ s/(.)$//;
        my $norm = $&;
        if($norm eq "T") {
            $norm = "tumor";
        } elsif ($norm eq "N") {
            $norm = "normal";
        }
        $names{$internal}=$common_name;
        $normal{$internal}=$norm;
    }

    my %samples;

    my $temp_dir = File::Temp::tempdir('Genome-InstrumentData-Commnd-Import-Microarray-Illumina-Multi-Sample-XXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1); 

    for my $k (sort(keys(%names))) {
        if(%excluded_names) {
            next if $excluded_names{$names{$k}}; 
        }
        if(%included_names) {
            next if not $included_names{$names{$k}};
        }        
        
        my (@individual,@sample);
        unless(@individual = Genome::Individual->get( common_name => $names{$k})) {
            $self->error_message("Could not locate a Genome::Individual record for ".$names{$k});
            die $self->error_message;
        }
        unless(@sample = Genome::Sample->get( source_id => $individual[0]->ORGANISM_ID,  common_name =>  $normal{$k})) {
            $self->error_message("Could not locate a Genome::Sample record for ".$names{$k}." ".$normal{$k}."\n");
            die $self->error_message;
        }
        unless(scalar(@individual) <= 1) {
            print "More than one individual was found for the common_name of: $names{$k}\n\n";
            for (@individual) {
                print "individual having organism_id: ".$_->organism_id."\n";
            }
            print "\nIn order to proceed with this command, either remove all but one individual with the above common_name, or run the command excluding the common_name of : $names{$k}\n\n";
            $self->error_message("More than one individual found, stopping import command.");
            die $self->error_message;
        }

        unless(scalar(@sample) <= 1) {
            print "More than one sample was found which relates to the organism_id: ".$individual[0]->ORGANISM_ID." \n\n";
            for (@sample) {
                print "sample having sample_id: ".$_->id."\n";
            }
            print "\nIn order to proceed with this command, either remove all but one sample with the above common_name, or run the command excluding the common_name of : $names{$k}\n\n";
            $self->error_message("More than one individual found, stopping import command.");
            die $self->error_message;
        }
        my $name = $sample[0]->name;
        $samples{$k} = $sample[0];
        $internal{$name}=$k;
    }


    unless(Genome::Model::Tools::Array::CreateGenotypesFromBeadstudioCalls->execute(
        genotype_file => "$path/$genotype",
        output_directory => "$temp_dir", 
        ucsc_array_file => $self->ucsc_array_file,)) {
            $self->error_message("Call to Genome::Model::Tools::Array::CreateGenotypesFromBeadstudioCalls failed");
            die $self->error_message;
    }
    print "finished creating genotypes.\n";   
    #my @genotypes = grep { -e $_ } glob("$temp_dir/*genotype");

    #my @genotypes = map { return $_.".genotype" } keys(%names);

    #for (sort(@genotypes)) {
    #    unless(-e $_) {
    #        $self->error_message("Could not find expected output file ".$_."\n");
    #        die $self->error_message;
    #    }
    #}


    #first_sample is being used to facilitate testing. Specifically, to avoid creating multiple test allocations.
    my $count=0;
    my @model_ids;

    for my $k (sort(keys(%samples))) {
        my $sample_name = $samples{$k}->name;
        #print "working on sample : ".$sample_name."\n";
        $self->status_message("working on sample ".$sample_name);
        my $num_samples = scalar(keys(%samples));
        print "working on sample ".$sample_name." # ".($count+1)." of $num_samples samples.\n";
        unless(Genome::InstrumentData::Command::Import::Microarray::Misc->execute(
                original_data_path => $path,
                sample_name => $sample_name,
                sequencing_platform => $self->sequencing_platform, )) {
            $self->error_message("unable to import sample data for ".$sample_name);
            die $self->error_message;
        }
        my $imported_instrument_data;
        unless($imported_instrument_data = Genome::InstrumentData::Imported->get(
                sample_name => $sample_name,
                original_data_path => $path,
                sequencing_platform => $self->sequencing_platform,
            )) {
            $self->error_message("unable to find imported data for ".$sample_name);
            die $self->error_message;
        }
        my $gen = "$temp_dir/$internal{$sample_name}.genotype";
        unless(-e $gen) {
            $self->status_message("no genotype file found for sample: ".$sample_name." expected file to be at ".$temp_dir."/".$internal{$sample_name}.".genotype");
            print "no genotype file found for sample: ".$sample_name." expected file to be at ".$temp_dir."/".$internal{$sample_name}.".genotype\n";
            die $self->status_message;
        }
        print "imported_instrument_data id = ".$imported_instrument_data->id."\n";
        print "Beginning copy of genotype data into allocation\n";
        unless(copy($gen,$imported_instrument_data->data_directory)){
            unless(-s "$imported_instrument_data->data_directory/$internal{$sample_name}.genotype") {
                $self->error_message("Unable to copy genotype file to data directory for sample:  ".$sample_name);
                die $self->error_message;
            }
        }
        print "completed copy of genotype data\n";
        $genotype_path = $imported_instrument_data->data_directory;
        $genotype_path_and_file = "$genotype_path/$internal{$sample_name}.genotype";
        unless(-e $genotype_path_and_file) {
            $self->error_message("no genotype file found for ".$sample_name);
            die $self->error_message;
        }

        unless(defined($processing_profile)) {
            $processing_profile = "illumina/wugc";
        }

        #create SNP Array Genotype (goldSNP)
        my $genotype_path_and_SNP = $genotype_path."/".$sample_name."_SNPArray.genotype";
        unless(Genome::Model::Tools::Array::CreateGoldSnpFromGenotypes->execute(    
            genotype_file1 => $genotype_path_and_file,
            genotype_file2 => $genotype_path_and_file,
            output_file    => $genotype_path_and_SNP,)) {

            $self->error_message("SNP Array Genotype creation failed");
            die $self->error_message;
        }
        $self->status_message("finished call to Genome::Model::Tools::Array::CreateGoldSnpFromGenotypes"); 

        #create genotype model
        my $define = Genome::Model->get( name => "$sample_name/$processing_profile");

        if($define) {
            print "found an existing model for $sample_name/$processing_profile.\n";
            $self->error_message("Found an existing model for $sample_name/$processing_profile");
            die $self->error_message
        }

        my $no_build;
        if($imported_instrument_data->id < 0) {
            $no_build = 1;
        } else {
            $no_build = 0;
        }
        unless($define = Genome::Model::Command::Define::GenotypeMicroarray->execute(     
                        file =>  $genotype_path_and_SNP,
                        processing_profile_name =>  $processing_profile,
                        subject_name =>  $sample_name,
                        no_build =>  $no_build,
                )) {
            $self->error_message("GenotpeMicroarray Model Define failed.");
            die $self->error_message;
        }

        push(@model_ids, $define->result_model_id);
        $count++;
        $self->status_message("finished call to Genome::Model::Command::Define::GenotypeMicroarray");
    }
    $self->result_model_ids(\@model_ids);
    print "\n\nModel ID's:\n";
    for (@model_ids) {
        print "\t\t".$_."\n";
    }
    return 1;
}


1;

    


    

