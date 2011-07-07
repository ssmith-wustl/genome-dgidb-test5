package Genome::Model::Tools::Newbler::StandardOutputs;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Newbler::StandardOutputs {
    is => 'Genome::Model::Tools::Newbler',
    has => [
        assembly_directory => {
            is => 'Text',
            doc => 'Path to assembly',
        },
        min_contig_length => {
            is => 'Number',
            doc => 'Minimum contig length to export',
        },
        default_gap_size => {
            is => 'Number',
            doc => 'Gap size to assign when newbler does not assign one',
        },
    ],
};

sub help_brief {
    'Tools to create standard output files for newbler assemblies';
}

sub help_detail {
    return <<"EOS"
gmt newbler standard-outputs --assembly-directory /gscmnt/111/newbler_assembly --min-contig-length 200 --default-gap-size 10
EOS
}

sub execute {
    my $self = shift;
    
    #create consed/edit_dir if not there
    unless ( -d $self->consed_edit_dir ) {
        $self->create_consed_dir;
    }

    #pcap style ace file
    my $ec_ace = Genome::Model::Tools::Newbler::ToPcapAce->create(
        assembly_directory => $self->assembly_directory,
        default_gap_size => $self->default_gap_size,
        min_contig_length => $self->min_contig_length,
    );
    if ( not $ec_ace->execute ) {
        $self->error_message("Failed to execute newbler to-pcap-ace");
        return;
    }

    #input fasta and qual from fastqs
    my $ec_inputs = Genome::Model::Tools::Newbler::InputsFromFastq->create(
        assembly_directory => $self->assembly_directory,
    );
    if ( not $ec_inputs->execute ) {
        $self->error_message("Failed to execute newbler inputs-from-fastq");
        return;
    }

    #contigs.bases and contigs.quals files
    my $ec_contigs = Genome::Model::Tools::Newbler::CreateContigsFiles->create(
        assembly_directory => $self->assembly_directory,
        min_contig_length => $self->min_contig_length,
    );
    if ( not $ec_contigs->execute ) {
        $self->error_message("Failed to execute newbler create-contigs-files");
        return;
    }

    #supercontigs.fasta and supercontigs.agp files
    my $ec_sctgs = Genome::Model::Tools::Newbler::CreateSupercontigsFiles->create(
        assembly_directory => $self->assembly_directory,
        default_gap_size => $self->default_gap_size,
        min_contig_length => $self->min_contig_length,
    );
    if ( not $ec_sctgs->execute ) {
        $self->error_message("Failed to execute newbler create-supercontigs-files");
        return;
    }

    return 1;
}

1;
