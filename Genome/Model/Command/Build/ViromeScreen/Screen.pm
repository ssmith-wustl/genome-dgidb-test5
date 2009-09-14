package Genome::Model::Command::Build::ViromeScreen::Screen;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ViromeScreen::Screen {
    is => 'Genome::Model::Command::Build::ViromeScreen',
};

sub execute {
    my $self = shift;

    unless (-d $self->build->dir) {
	$self->error_message("Run directory does not exist");
	return;
    }

    unless (-s $self->build->fasta_file) {
	$self->error_message("Run fasta file does not exist");
	return;
    }

    unless (-s $self->build->barcode_file) {
	$self->error_message("Run barcode file does not exist");
	return;
    }

    my $run = Genome::Model::Tools::ViromeScreening->create (
	fasta_file   => $self->build->fasta_file,
	barcode_file => $self->build->barcode_file,
	dir          => $self->build->dir,
	logfile      => $self->build->logfile, #THIS IS NOT AN INPUT FILE??
    );

    unless ($run) {
	$self->error_message("Failed to create virome screen run");
	return;
    }

    unless ($run->execute) {
	$self->error_message("Failed virome screen run");
	return 1;
    }

    return 1;
}

1;
