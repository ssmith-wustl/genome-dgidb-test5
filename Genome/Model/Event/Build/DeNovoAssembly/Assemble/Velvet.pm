package Genome::Model::Event::Build::DeNovoAssembly::Assemble::Velvet;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Assemble::Velvet {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::Assemble',
};

sub execute { 
    my $self = shift;
    
    # Colalted fastq - verify
    my $collated_fastq_file = $self->build->collated_fastq_file;
    unless ( -s $collated_fastq_file ) {
        $self->error_message("Velvet fastq file does not exist");
        return;
    }   

    # Run OBV
    my %assembler_params = $self->processing_profile->assembler_params_as_hash();
    my $run = Genome::Model::Tools::Velvet::OneButton->create(
        file => $collated_fastq_file,
        output_dir => $self->build->data_directory,
        version => $self->processing_profile->assembler_version,
        genome_len => $self->build->genome_size,
        %assembler_params,
    );

    unless ($run) {
        $self->error_message("Failed velvet create");
        return;
    }

    unless ($run->execute) {
        $self->error_message("Failed to run velvet");
        return;
    }

    # Remove unnecessary files
    $self->_remove_unnecessary_files
        or return; # error in sub
    
    # Final version of contigs fasta - verify exists
    my $final_contigs_fasta = $self->build->contigs_fasta_file;
    unless ( -s $final_contigs_fasta ) {
        $self->error_message("No contigs fasta ($final_contigs_fasta) file produced from running one button velvet.");
        return;
    }

    return 1;
}

sub _remove_unnecessary_files {
    my $self = shift;

    # contigs fasta files
    my @contigs_fastas_to_remove = glob($self->build->data_directory.'/*contigs.fa');
    unless ( @contigs_fastas_to_remove ) { # error here??
        $self->error_message("No contigs fasta files produced from running one button velvet.");
        return;
    }
    my $final_contigs_fasta = $self->build->contigs_fasta_file;
    for my $contigs_fasta_to_remove ( @contigs_fastas_to_remove ) {
        next if $contigs_fasta_to_remove eq $final_contigs_fasta;
        unless ( unlink $contigs_fasta_to_remove ) {
            $self->error_message(
                "Can't remove unnecessary contigs fasta ($contigs_fasta_to_remove): $!"
            );
            return;
        }
    }

    # log and timing files
    for my $glob (qw/ logfile timing /) {
        for my $file ( glob($self->build->data_directory.'/*-'.$glob) ) {
            unless ( unlink $file ) {
                $self->error_message("Can't remove unnecessary file ($glob => $file): $!");
                return;
            }
        }
    }

    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.pm $
#$Id: PrepareInstrumentData.pm 45247 2009-03-31 18:33:23Z ebelter $
