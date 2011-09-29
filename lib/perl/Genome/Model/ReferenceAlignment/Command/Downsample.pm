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
    my $bam = $build->whole_rmdup_bam_file;

    unless(-e $bam){
        die $self->error_message("Could not locate bam at: ". $bam);
    }

    my $flagstat_file = $self->_get_or_create_flagstat($bam);

    $self->status_message("Found or created a flagstat file, proceeding to downsampling.");

    my $flagstat = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($flagstat_file);

    my $total_readcount = $flagstat->{total_reads};

    $self->status_message("Total read-count in the original bam: ".$total_readcount);

    my ($id) = $model->instrument_data;

    unless($id){
        die $self->error_message("Could not locate intrument data on the model to determine read-length");
    }

    my $read_length = $id->read_length;
    
    unless($read_length){
        die $self->error_message("Could not determine read-length from instrument_data: ".$id->id);
    }
    $self->status_message("Read Length: ".$read_length);

    my $total_bases = $read_length * $total_readcount;

    $self->status_message("Total Bases: ".$total_bases);

    my $downsample_ratio = $new_coverage / $total_bases;

    if($downsample_ratio >= 1.0){
        die $self->error_message("The downsample ratio ended up being >= 1. You must specify a coverage_in_gb that is lower than the existing bam.");
    }

    $self->status_message("Downsample ratio = ".$downsample_ratio);

    my $temp = Genome::Sys->create_temp_file_path;

    my $ds_cmd = Genome::Model::Tools::Picard::Downsample->create(
        input_file => $bam,
        output_file => $temp,
        downsample_ratio => $downsample_ratio,
    );

    unless($ds_cmd->execute){
        die $self->error_message("Could not complete picard downsample command.");
    } 
    $self->status_message("Downsampled bam has been created at: ".$temp);

    my $imported_bam = $self->_import_bam($temp,$model);

    unless($imported_bam){
        die $self->error_message("Could not import bam");
    }

    $self->status_message("Your new instrument-data id is: ".$imported_bam->id);
 
    #my $new_model = $self->_define_new_model($model,$imported_bam);
    return 1;
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

    my $dir = dirname($bam);
    my $filename = $dir."/all_sequences.bam";
    rename $bam, $filename; 

    my $sample = $model->subject->id;
    unless(Genome::Sample->get($sample)){
        die $self->error_message("Cannot locate a sample to use for importing downsampled bam!");
    }

    my %params = (
        original_data_path => $filename,
        sample => $sample,
        create_library => 1,
        import_source_name => 'TGI',
        description => "Downsampled aligned bam",
        reference_sequence_build_id => $model->reference_sequence_build_id,
    );
    $params{target_region} = $model->target_region_set_name unless not defined($model->target_region_set_name);

    print Data::Dumper::Dumper(\%params);

    my $import_cmd = Genome::InstrumentData::Command::Import::Bam->execute(
        %params
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

1;
