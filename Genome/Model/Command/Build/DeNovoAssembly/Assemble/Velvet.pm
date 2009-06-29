package Genome::Model::Command::Build::DeNovoAssembly::Assemble::Velvet;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Command::Build::DeNovoAssembly::Assemble::Velvet {
    is => 'Genome::Model::Command::Build::DeNovoAssembly::Assemble',
};

sub execute { 
    my $self = shift;

    unless (-s $self->build->velvet_fastq_file) {
        $self->error_message("Velvet fastq file does not exist");
        return;
    }

    my $assemble_params = $self->model->processing_profile->get_assemble_params;
    unless ( $assemble_params ) {
        $self->error_message("Problem getting assembler params");
        return;
    }

    my $run = Genome::Model::Tools::Velvet::Run->create(
        file_name => $self->build->velvet_fastq_file,
        directory => $self->build->data_directory,
        version => $self->model->assembler_version,
        %$assemble_params,
    );

    unless ($run) {
        $self->error_message("Failed velvet create");
        return;
    }

    unless ($run->execute) {
        $self->error_message("Failed to run velvet");
        return;
    }

    return 1;
}

sub valid_params {
    my $class = 'Genome::Model::Tools::Velvet';
    return $class->valid_params();
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.pm $
#$Id: PrepareInstrumentData.pm 45247 2009-03-31 18:33:23Z ebelter $
