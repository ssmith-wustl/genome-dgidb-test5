package Genome::Model::Event::Build::ViromeScreen::PrepareInstrumentData;

# uses modules at the top that arent actually used.  as the comment in _prepare_454_data suggests it should symlink its input fasta instead of copy

use strict;
use warnings;

use Genome;
use File::Copy;
use Data::Dumper;

class Genome::Model::Event::Build::ViromeScreen::PrepareInstrumentData {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $data_type = $self->model->processing_profile->sequencing_platform;

    my $method = '_prepare_'.$data_type.'_data';
    
    unless ($self->can($method)) {
	$self->error_message("Invalid sequencing platform name: $data_type");
	return;
    }

    unless ($self->$method()) {
	$self->error_message("Failed to execute prepare instrument data step");
	return;
    }

    return 1;
}

sub _prepare_454_data {
    my $self = shift;

    my @instrument_data = $self->model->instrument_data;
    unless (@instrument_data) {
	$self->error_message("Error: No instrument data assigned to model");
	return;
    }

    #FOR NOW JUST HAVE IT WORK WITH DATA SETS WITH SINGLE DATA
    unless (@instrument_data == 1) {
	$self->error_message("Error: more than one instrument data found");
	return;
    }

    my $fasta_name = $self->model->subject_name.'.fna';
    my $screen_dir = $self->_create_screen_directory();

    unless (-d $screen_dir) {
	$self->error_message("Error: Failed to create virome screen directory");
	return;
    }

    my $fasta_file = $screen_dir.'/'.$fasta_name;

    #CREATE A LINK INSTEAD??
    unless (copy ($instrument_data[0]->fasta_file, $fasta_file)) {
	$self->error_message("Error: Unable to copy fasta to screen dir");
	return;
    }

    unless (-s $fasta_file) {
	$self->error_message("Error: Input file does not exist: $fasta_file");
	return;
    }

    return 1;
}

sub _create_screen_directory {
    my $self = shift;
    
    Carp::confess unless $self->build;
    my $screen_dir = $self->build->data_directory.'/virome_screen';

    unless (-d $screen_dir) {
	mkdir ($screen_dir, 0777);
    }

    return $screen_dir;
}

1;

#$HeadURL$
#$Id$
