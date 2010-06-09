package Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Velvet;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Velvet {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::PostAssemble',
};

sub execute {
    my $self = shift;

    #this is probably not necessary to do here
    unless (-d $self->build->data_directory) {
        $self->error_message("Invalid build data directory: ".$self->build->data_directory);
        return;
    }

    #TODO - use G::util
    Genome::Utility::FileSystem->create_directory($self->build->edit_dir);
    chomp (my $time = `date "+%a %b %e %T %Y"`);

    #make ace file .. 
    my $to_ace = Genome::Model::Tools::Velvet::ToAce->create(
        #these files are validated in ToAce mod
        seq_file => $self->build->sequences_file,
        afg_file => $self->build->assembly_afg_file,
        time => $time,
        out_acefile => $self->build->velvet_ace_file,
    );
    unless ($to_ace->execute) {
        $self->error_message("Failed to run velvet-to-ace");
        return;
    }

    #create standard assembly output files
    my $ec = Genome::Model::Tools::Velvet::CreateAsmStdoutFiles->execute(
        input_fastq_file => $self->build->collated_fastq_file,
        directory => $self->build->data_directory,
    );
    unless ($ec) {
        $self->error_message("Failed to run create asm stdout files");
        return;
    }

    return $self->_generate_summary_report;
}

1;

#$HeadURL$
#$Id$
