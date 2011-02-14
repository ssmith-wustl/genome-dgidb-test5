package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData',
};

sub execute {
    my $self = shift;

    $self->_dump_and_link_instrument_data
        or return;

    my @amplicon_set_names = $self->build->amplicon_set_names;
    Carp::confess('No amplicon set names for '.$self->build->description) if not @amplicon_set_names; # bad

    $self->_raw_reads_fasta_and_qual_writer
        or return;

    my $attempted = 0;
    for my $name ( @amplicon_set_names ) {
        my $amplicon_set = $self->build->amplicon_set_for_name($name);
        next if not $amplicon_set; # ok
        while ( my $amplicon = $amplicon_set->next_amplicon ) {
            $attempted++;
            $self->_prepare_instrument_data_for_phred_phrap($amplicon)
                or return;
        }
    }

    $self->build->amplicons_attempted($attempted);

    return 1;
}

sub _raw_reads_fasta_and_qual_writer {
    my $self = shift;

    unless ( $self->{_raw_reads_fasta_and_qual_writer} ) {
        $self->{_raw_reads_fasta_and_qual_writer} = Genome::Utility::BioPerl::FastaAndQualWriter->create(
            fasta_file => $self->build->raw_reads_fasta_file,
            qual_file => $self->build->raw_reads_qual_file,
        ) or return;
    }

    return $self->{_raw_reads_fasta_and_qual_writer};
}

#< Dumping/Linking Instrument Data >#
sub _dump_and_link_instrument_data {
    my $self = shift;

    unless ( $self->model->sequencing_center eq 'gsc' ) {
        # TODO add logic for other centers...
        return 1;
    }

    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) { # should not happen
        $self->error_message('No instrument data found for '.$self->description);
        return;
    }

    for my $instrument_data ( @instrument_data ) {
        # dump
        unless ( $instrument_data->dump_to_file_system ) {
            $self->error_message(
                sprintf(
                    'Error dumping instrument data (%s <Id> %s) assigned to model (%s <Id> %s)',
                    $instrument_data->run_name,
                    $instrument_data->id,
                    $self->model->name,
                    $self->model->id,
                )
            );
            return;
        }
        # link
        unless ( $self->build->link_instrument_data($instrument_data) ) {
            $self->error_message(
                sprintf(
                    'Error linking instrument data (%s <Id> %s) to model (%s <Id> %s)',
                    $instrument_data->run_name,
                    $instrument_data->id,
                    $self->model->name,
                    $self->model->id,
                )
            );
            return;
        }
    }

    return 1;
}

#< Phred, Phred to Fasta >#
sub _prepare_instrument_data_for_phred_phrap {
    my ($self, $amplicon) = @_;

    my $scfs_file = $self->build->create_scfs_file_for_amplicon($amplicon);
    my $phds_file = $self->build->phds_file_for_amplicon($amplicon);
    my $fasta_file = $self->build->reads_fasta_file_for_amplicon($amplicon);
    my $qual_file = $self->build->reads_qual_file_for_amplicon($amplicon);
    
    # Phred
    my $scf2phd = Genome::Model::Tools::PhredPhrap::ScfToPhd->create(
        chromat_dir => $self->build->chromat_dir,
        phd_dir => $self->build->phd_dir,
        phd_file => $phds_file,
        scf_file => $scfs_file,
    );
    unless ( $scf2phd ) {
        $self->error_message("Can't create scf to phd command");
        return;
    }
    unless ( $scf2phd->execute ) {
        $self->error_message("Can't execute scf to phd command");
        return;
    } 
    
    # Phred to Fasta
    my $phd2fasta = Genome::Model::Tools::PhredPhrap::PhdToFasta->create(
        fasta_file => $fasta_file,
        phd_dir => $self->build->phd_dir,
        phd_file => $phds_file,
    );
    unless ( $phd2fasta ) {
        $self->error_message("Can't create phd to fasta command");
        return;
    }
    unless ( $phd2fasta->execute ) {
        $self->error_message("Can't execute phd to fasta command");
        return;
    }
    
    # Write the 'raw' read fastas
    my $reader = Genome::Utility::BioPerl::FastaAndQualReader->create(
        fasta_file => $fasta_file,
        qual_file => $qual_file,
    ) or return;
    while ( my $bioseq = $reader->next_seq ) {
        $self->_raw_reads_fasta_and_qual_writer->write_seq($bioseq)
            or return;
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
