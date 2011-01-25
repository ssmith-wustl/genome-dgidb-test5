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
    sample_name_list => {
        is => 'Text',
        doc => 'The list of samples associated with the FinalReport file.',
        is_many => 1,
        is_optional => 1,
    },
    sample_name => {
        is => 'Text',
        doc => 'The tool will automagically populate this to multiple',
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
        doc => 'The tool will automagically populate this to be illumina genotype array',
        valid_values => ['illumina genotype array', 'illumina expression array', 'affymetrix genotype array', '454','sanger','unknown'],
        is_optional => 1,
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
    exclude_sample_names => {
        is => 'Text',
        is_optional => 1,
        doc => 'sample names (names like H_KU-16021-D801387), delineated by commas, to be excluded from the import command.',
    },
    include_sample_names => {
        is => 'Text',
        is_optional => 1,
        doc => 'sample names (names like H_KU-16021-D801387), delineated by commas, to be included in the import command.',
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
);
    
class Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArrayMulti {
    is => 'Genome::Command::Base',
    has => [%properties],
    doc => 'import external microarray instrument data',
};

sub execute {
    my $self = shift;
    $self->sample_name("multiple");
    $self->sequencing_platform("illumina genotype array");
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
    my $sample_map;
    my $illumina_manifest;
    my $forward_strand_report;

    if(defined($self->exclude_sample_names) and not defined($self->include_sample_names)) {
        %excluded_names = map { $_ => 1} split( ',', $self->exclude_sample_names);
        $self->status_message("Found exclude-sample-names.");
        print $self->status_message;
        for (sort(keys(%excluded_names))) {
            print "Exclude sample :  ".$_."\n";
        }
    }
    if(defined($self->include_sample_names) and not defined($self->exclude_sample_names)) {
        %included_names = map { $_ => 1} split( ',', $self->include_sample_names);
        $self->status_message("Found include-sample-names.");
        print $self->status_message;
        for (sort(keys(%included_names))) {
            print "Include sample :  ".$_."  \$included_names{\$_}=".$included_names{$_}."\n";
        }
    }
    if(defined($self->include_sample_names) and defined($self->exclude_sample_names)) {
        $self->error_message("You may not simultaneously include and exclude sample names.");
        die $self->error_message;
    }

    unless(defined($self->ucsc_array_file)) {
        $self->ucsc_array_file("/gscmnt/sata135/info/medseq/dlarson/snpArrayIllumina1M");
    }

    my $path = $self->original_data_path;

    my @files = glob( $path."/*" );


    #Find the exact file names of the Final Report and the Sample Map.    
    for (@files) {
        if ($_ =~ /FinalReport\.(txt|csv)/) {
            $genotype = $_;
            next;
        }
        if ($_ =~ /Sample_Map/) {
            $sample_map = $_;
            next;
        }
        if(defined($sample_map) && defined($genotype)) {
            last;
        }
    }

    print "genotype = ".$genotype."\n";
    print "sample map = ".$sample_map."\n";

    my $sample_map_fh;
    unless($sample_map_fh = new IO::File $sample_map,"r"){
        $self->error_message("Could not open file ".$sample_map);
        die $self->error_message;
    }

    my $line = $sample_map_fh->getline;
    my %names;
    my %normal;
    my %internal;
    my %samples;
    my %sample_names;
    my $split_char;
    if((not defined($split_char))&& ($line =~ /\,/)) {
        $split_char = ",";
        $self->status_message("Using comma as the delineating character for files.");
        print $self->status_message;
    } elsif (not defined($split_char) && ($line =~ /\t/)) {
        $split_char = "\t";
    } elsif (not defined($split_char)) {
        die "couldn't find the proper character used to delineate the Sample_Map file";
    }

    #extract sample_name from sample mapping, and include or exclude as directed by parameters
    while($line = $sample_map_fh->getline) {
        my @stuff = split $split_char, $line;
        my $sample_name=$stuff[1];
        my $internal_name=$stuff[2];
        if (scalar(keys(%included_names))) {
            unless(defined($included_names{$sample_name})) {
                next;
            }
        } elsif (scalar(keys(%excluded_names))) {
            if (defined($excluded_names{$sample_name})) {
                next;
            }
        }
        $sample_names{$internal_name} = $sample_name;
        $internal{$sample_name} = $internal_name;
    }

    unless(scalar(keys(%sample_names))) {
        $self->error_message("Found no samples / excluded all samples");
        die $self->error_message;
    }

    #Grab sample objects and toss them into the samples hash    
    for(sort(keys(%sample_names))) {
        print "sample_name = ".$_."\n";
        my $local_sample = Genome::Sample->get( name => $sample_names{$_} );
        unless($local_sample) {
            $self->error_message("Could not locate sample by the name of $sample_names{$_}.");
            die $self->error_message;
        }
        $samples{$_} = $local_sample;
        print "Found sample: ".$local_sample->name." to associate with barcode: ".$_."\n";
    }


    my $temp_dir = File::Temp::tempdir('Genome-InstrumentData-Commnd-Import-Microarray-Illumina-Multi-Sample-XXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1); 

    #create genotype files from machine data, store them on tmp disk, to be copied to individual allocations on a per-sample basis.
    $self->status_message("Now running Genome::Model::Tools::Array::CreateGenotypesFromBeadstudioCalls");
    print $self->status_message."\n";
    unless(Genome::Model::Tools::Array::CreateGenotypesFromBeadstudioCalls->execute(
        genotype_file => $genotype,
        output_directory => "$temp_dir", 
        ucsc_array_file => $self->ucsc_array_file,)) {
            $self->error_message("Call to Genome::Model::Tools::Array::CreateGenotypesFromBeadstudioCalls failed");
            die $self->error_message;
    }
    print "finished call to Genome::Model::Tools::Array::CreateGenotypesFromBeadstudioCalls.\n";   


    my $count=0;
    my @model_ids;

    #This loops through the list of samples and creates instrument-data records for each, copies the genotype file into the associated allocation,
    # and then deposits the goldSNP file, then kicks off a define/build model.
    for my $k (sort(keys(%samples))) {
        my $sample_name = $samples{$k}->name;
        my $sample = $samples{$k};

        $self->status_message("working on sample ".$sample_name);
        my $num_samples = scalar(keys(%samples));
        print "working on sample ".$sample_name." # ".($count+1)." of $num_samples samples.\n";

        my $library = Genome::Library->get(sample=>$sample, name =>$sample->name . "-microarraylib");
        unless ($library) {
            $library = Genome::Library->create(sample=>$sample, name =>$sample->name . "-microarraylib");
        }
        unless ($library) {
            $self->error_message("Can't get or create library for " . $sample->name . "-microarraylib");
            die $self->error_message;
        }
        
        unless(Genome::InstrumentData::Command::Import::Microarray::Misc->execute(
                original_data_path => $path,
                sample_name => $sample_name,
                library_name => $library->name,
                sequencing_platform => $self->sequencing_platform,
                reference_sequence_build => $self->reference_sequence_build)) {
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

        unless(Genome::InstrumentData::Command::Import::Genotype->create(
                source_data_file    => $gen,
                sample_name         => $sample_name,
                library_name        => $library->name,
                reference_sequence_build => $self->reference_sequence_build,
                define_model        => 1,)){
            $self->error_message("Could not define model for ".$sample_name."\n");
            die $self->error_message;
        }
    }
    return 1;
}


1;

    


    

