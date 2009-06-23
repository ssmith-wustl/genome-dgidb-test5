package Genome::Model::Tools::RepeatMasker::Run;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RepeatMasker::Run {
    is => ['Genome::Model::Tools::RepeatMasker','Genome::Utility::FileSystem'],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless ($self->output_directory) {
        require Cwd;
        my $cwd = Cwd::cwd();
        $self->output_directory($cwd);
    }

    unless ($self->create_directory($self->output_directory)) {
        $self->error_message('Failed to create output directory '. $self->output_directory);
        die($self->error_message);
    }
    unless ($self->validate_directory_for_write_access($self->output_directory)) {
        $self->error_message('Failed to validate directory for writing '. $self->output_directory);
        die($self->error_message);
    }
    unless ($self->validate_file_for_reading($self->fasta_file)) {
        $self->error_message('Failed to validate file for reading '. $self->layers_file_path);
        die($self->error_message);
    }
    return $self;
}


sub execute {
    my $self = shift;

    my $options = ' -species '. $self->species;
    if ($self->mask && $self->mask ne '-n') {
        $options .=  ' '. $self->mask;
    }
    if ($self->sensitivity) {
        $options .= ' '. $self->sensitivity;
    }
    $options .= ' -dir '. $self->output_directory;
    my $cmd = 'RepeatMasker '. $options .' '. $self->fasta_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
    );
    return 1;
}

1;
