package Genome::Model::SomaticValidation::Command::ImportVariants;

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticValidation::Command::ImportVariants {
    is => 'Command::V2',
    has_input => [
        variant_file_list => {
            is => 'Text',
            doc => 'File listing the variants to be uploaded',
        },
        models => {
            is => 'Genome::Model::SomaticVariation',
            doc => 'The somatic variation models for the variants in the list, provided as a group or comma-delimited list',
            is_many => 1,
        },
    ],
    has_optional_output => [
        results => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            is_many => 1,
            doc => 'The results from running this command',
        },
    ],
    doc => 'enter the variants for validation from many previous somatic-variation runs at once',
};

sub sub_command_category { 'analyst tools' }

sub execute {
    my $self = shift;

    #First, find all the files we'll be working with
    my %data;

    my $variant_file_list_fh = Genome::Sys->open_file_for_reading($self->variant_file_list);

    my $variant_type;
    while(my $line = <$variant_file_list_fh>) {
        chomp $line;
        if($line =~ m!.*/(\w+\d+)/[^/]*!) {
            my $patient = $1;

            $data{$variant_type}{$patient} ||= [];
            push @{ $data{$variant_type}{$patient} }, $line;
        } elsif(grep($_ eq $line, 'snvs', 'indels', 'svs')) {
            $variant_type = $line; #header indicating SNVs, indels, or SVs
            $variant_type =~ s/s$//;
        } else {
            die $self->error_message('Could not determine patient for this file: ' . $line);
        }
    }

    my %models_by_patient_common_name;
    for my $m ($self->models) {
        my $subject = $m->subject;
        my $source = $subject->source;
        unless($source) {
            die $self->error_message('No patient found linked to subject of model ' . $m->__display_name__);
        }

        my $common_name = $source->common_name;
        unless($common_name) {
            die $self->error_message('No common name found on patient ' . $source->__display_name__ . ' for model ' . $m->__display_name__);
        }

        if(exists $models_by_patient_common_name{$common_name}) {
            die $self->error_message('Multiple models provided for ' . $common_name . '(' . $m->__display_name__ . ' and ' . $models_by_patient_common_name{$common_name});
        }
        $models_by_patient_common_name{$common_name} = $m;
    }

    my @results;
    for my $variant_type (keys %data) {
        for my $patient (keys %{ $data{$variant_type} }) {
            my $model = $models_by_patient_common_name{$patient};

            my $result = $self->_upload_result($model, $variant_type, @{ $data{$variant_type}{$patient} });
            push @results, $result;
        }
    }

    $self->results(\@results);
    $self->status_message('Successfully created results.');
    $self->status_message('Result IDs: ' . join(',', map($_->id, @results)));

    return 1;
}

sub _upload_result {
    my $self = shift;
    my $model = shift;
    my $variant_type = shift;
    my @files = @_;

    my $file;
    if(scalar(@files) > 1) {
        $file = Genome::Sys->create_temp_file_path;
        Genome::Sys->cat(
            input_files => \@files,
            output_file => $file,
        );
    } elsif (scalar(@files) == 1) {
        $file = $files[0];
    } else {
        die '_upload_result called with no variant files';
    }

    my $build = $model->last_complete_build;
    unless($build) {
        die $self->error_message('No complete build found for model ' . $model->__display_name__);
    }

    my $result_cmd = Genome::Model::SomaticValidation::Command::ManualResult->create(
        source_build => $build,
        variant_file => $file,
        variant_type => $variant_type,
        format => 'annotation',
        description => 'generated from ' . $self->variant_file_list,
    );

    unless($result_cmd->execute) {
        die $self->error_message('Failed to create result for model ' . $model->__display_name__ . ' ' . $variant_type . 's using files: ' . join(', ', @files));
    }

    return $result_cmd->manual_result;
}


1;

