package Genome::Model::ReferenceAlignment::Command::Downsample;

use strict;
use warnings;
use Genome;
use File::Basename;

class Genome::Model::ReferenceAlignment::Command::Downsample {
    is => 'Command::V2',
    doc => 'Merge merged.vcf outputs from many samples into one vcf',
    has => [
        model => {
            is => 'Genome::Model',
            shell_args_position => 1,
            doc => 'Model to operate on',
            is_optional => 0,
            is_input => 1,
        },
        coverage_in_gb => {
            is => 'Text',
            doc => "Set this to the amount of bases to lower the input to, in GB. 1.5 = 1,500,000,000 bases",
            is_optional => 0,
            is_input => 1,
        },
        random_seed => {
            is => 'Text',
            doc => 'Set this equal to the reported random seed to reproduce previous results',
            is_optional => 1,
        },
    ],
};

sub help_detail {
    return <<EOS 
    Use this to downsample merged deduped bams
EOS
}

sub execute {
    my $self = shift;

    my $new_coverage = $self->coverage_in_gb * 1000000000;  #convert gigabases to bases

    my $model = $self->model;
    unless($model){
        die $self->error_message("Could not locate model!");
    }
    my $build = $model->last_succeeded_build;
    unless($build){
        die $self->error_message("Could not locate a succeeded build for model: ".$model->id);
    }

    $self->status_message("Using Build: ".$build->id);

    my $bam = $build->whole_rmdup_bam_file;
    unless(-e $bam){
        die $self->error_message("Could not locate bam at: ". $bam);
    }


    my $total_readcount = $self->_get_readcount($bam);
    $self->status_message("Total read-count in the original bam: ".$total_readcount);

    #TODO this currently assumes homogenous read-length instrument-data
    my $read_length = $self->_get_readlength($model);
    $self->status_message("Read Length: ".$read_length);

    my $total_bases = $read_length * $total_readcount;
    $self->status_message("Total Bases: ".$total_bases);

    #Calculate downsample ratio by taking the ratio of desired coverage to the current total bases, 
    # round to 5 decimal places
    my $downsample_ratio = sprintf("%.5f", $new_coverage / $total_bases );
    unless($downsample_ratio < 1.0){
        die $self->error_message("The downsample ratio ended up being >= 1. You must specify a coverage_in_gb that is lower than the existing bam.");
    }
    $self->status_message("Downsample ratio = ".$downsample_ratio);

    #Place the output of the downsampling into temp
    my $temp = Genome::Sys->create_temp_file_path;

    #Get or create a random seed from combining PID and current time
    my $seed = (defined($self->random_seed)) ? $self->random_seed : ($$ + time);
    $self->status_message("Random Seed: ".$seed);

    my $ds_cmd = Genome::Model::Tools::Picard::Downsample->create(
        input_file => $bam,
        output_file => $temp,
        downsample_ratio => $downsample_ratio,
        random_seed => $seed,
    );
    unless($ds_cmd->execute){
        die $self->error_message("Could not complete picard downsample command.");
    } 
    $self->status_message("Downsampled bam has been created at: ".$temp);

    #create an imported instrument-data record
    my $imported_bam = $self->_import_bam($temp,$model,$downsample_ratio);
    unless($imported_bam){
        die $self->error_message("Could not import bam");
    }
    $self->status_message("Your new instrument-data id is: ".$imported_bam->id);

    #TODO add code to create new models using the newly imported instrument-data
    #my $new_model = $self->_define_new_model($model,$imported_bam);

    return 1;
}

sub get_or_create_library {
    my $self = shift;
    my $sample = shift;
    my $library;
    my $new_library_name = $sample->name . "-extlibs";
    my $try_count = 0;

    #try creating or getting the library until it succeeds or max tries reached
    while(!$library && ($try_count < 5)){
        $try_count++;
        my $time = int(rand(10));
        $self->status_message( "Waiting $time seconds before trying to get or create a library.\n" );
        sleep $time;
        UR::Context->reload("Genome::Library", name => $new_library_name);
        $library = Genome::Library->get(name => $new_library_name);

        if($library){
            next;
        } else {
            my $cmd = "genome library create --name ".$new_library_name." --sample ".$sample->id;
            my $result  = Genome::Sys->shellcmd( cmd => $cmd );
            unless($result){
                die $self->error_message("Could not create new library.");
            }
        }
        UR::Context->reload("Genome::Library",name => $new_library_name);
        $library = Genome::Library->get(name => $new_library_name);
    }

    unless($library){
        die $self->error_message("Could not get or create library.");
    }

    return $library;
}

sub _define_new_model {
    my $self = shift;
    my $model = shift;
    my $id = shift;
    my $new_model = Genome::Model->copy(
        model => $model,
        model_overrides => ['instrument_data='],
    );
    
    $DB::single=1;

    return $new_model;
}

sub _import_bam {
    my $self = shift;
    my $bam = shift;
    my $model = shift;
    my $downsample_ratio = shift;

    my $dir = dirname($bam);
    my $filename = $dir."/all_sequences.bam";
    rename $bam, $filename; 

    my $sample_id = $model->subject->id;
    my $sample = Genome::Sample->get($sample_id);
    unless($sample){
        die $self->error_message("Cannot locate a sample to use for importing downsampled bam!");
    }

    my $library = $self->get_or_create_library($sample);

    my %params = (
        original_data_path => $filename,
        sample => $sample->id,
        create_library => 1,
        import_source_name => 'TGI',
        description => "Downsampled bam, ratio=".$downsample_ratio,
        reference_sequence_build_id => $model->reference_sequence_build_id,
        library => $library->id,
    );
    $params{target_region} = $model->target_region_set_name || "none";

    my $import_cmd = Genome::InstrumentData::Command::Import::Bam->execute(
        %params,
    );
    unless($import_cmd){
        die $self->error_message("Could not execute bam import command!");
    }

    my $id = Genome::InstrumentData::Imported->get(id => $import_cmd->result);
    unless($id){
        die $self->error_message("Could not retrieve newly created instrument-data");
    }
    return $id
}

sub _get_or_create_flagstat {
    my $self = shift;
    my $bam = shift;

    my $flagstat_file = $bam.".flagstat";
    unless(-s $flagstat_file){
        $self->status_message("Couldn't locate flagstat file, generating one now");
        my $flag_cmd = Genome::Model::Tools::Sam::Flagstat->create(
            bam_file => $bam,
            output_file => $flagstat_file,
        );
        unless($flag_cmd->execute){
            die $self->error_message("Could not create a flagstat file.");
        }
    }
    return $flagstat_file;
}

sub _get_readcount {
    my $self = shift;
    my $bam = shift;

    my $flagstat_file = $self->_get_or_create_flagstat($bam);
    $self->status_message("Found or created a flagstat file, proceeding to downsampling.");
    my $flagstat = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($flagstat_file);
    return $flagstat->{total_reads};
}

sub _get_readlength {
    my $self = shift;
    my $model = shift;
    my @id = grep{ defined($_)} $model->instrument_data;
    $self->status_message("Found ". scalar(@id) . " instrument-data records associated with model ".$model->id);
    my $readlength;
    for my $id (@id){
        if(defined($readlength)){
            unless($id->read_length == $readlength){
                die $self->error_message("Found instrument data with different read lengths: ". $readlength."  and  ".$id->read_length."\n"
                    ."This tool currently works only on homogenous read length models.");
            }
        } else {
            $readlength = $id->read_length;
        }
    }
    unless($readlength){
        die $self->error_message("Could not locate intrument data on the model to determine read-length");
    }
    return $readlength;
}

1;
