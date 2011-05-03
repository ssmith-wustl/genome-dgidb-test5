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

    my %trimmer_params = $self->processing_profile->trimmer_params_as_hash;
    my %assembler_params = $self->processing_profile->assembler_params_as_hash;

    my ($attempted, $reads_attempted, $reads_processed) = (qw/ 0 0 0 /);
    for my $name ( @amplicon_set_names ) {

        my $amplicon_set = $self->build->amplicon_set_for_name($name);
        next if not $amplicon_set; # ok

        my $writer = $self->build->fasta_and_qual_writer_for_type_and_set_name('processed', $amplicon_set->name);
        return if not $writer;

        while ( my $amplicon = $amplicon_set->next_amplicon ) {
            $attempted++;
            $reads_attempted += @{$amplicon->{reads}};
            my $prepare_ok = $self->_prepare($amplicon);
            return if not $prepare_ok;

            my $trim_ok = $self->_trim($amplicon, %trimmer_params);
            return if not $trim_ok;

            my $assemble_ok = $self->_assemble($amplicon, %assembler_params);
            return if not $assemble_ok;

            $self->build->load_seq_for_amplicon($amplicon)
                or next; # ok
            $writer->write([$amplicon->{seq}]);
            $reads_processed += @{$amplicon->{reads_processed}};
        }
    }

    $self->build->amplicons_attempted($attempted);
    $self->build->reads_attempted($reads_attempted);
    $self->build->reads_processed($reads_processed);
    $self->build->reads_processed_success( $reads_attempted > 0 ?  sprintf('%.2f', $reads_processed / $reads_attempted) : 0 );

    return 1;
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
sub _prepare {
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
    my $reader = Genome::Model::Tools::FastQual::PhredReader->create(
        files => [ $fasta_file, $qual_file ],
    );
    return if not $reader;
    while ( my $seq = $reader->read ) {
        $self->_raw_reads_fasta_and_qual_writer->write($seq)
            or return;
    }
    
    return 1;
}

sub _raw_reads_fasta_and_qual_writer {
    my $self = shift;

    unless ( $self->{_raw_reads_fasta_and_qual_writer} ) {
        my $fasta_file = $self->build->raw_reads_fasta_file;
        unlink $fasta_file if -e $fasta_file;
        my $qual_file = $self->build->raw_reads_qual_file;
        unlink  $qual_file if -e $qual_file;
        my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file, $qual_file, ]);
        if ( not $writer ) {
            $self->error_message('Failed to create phred reader for raw reads');
            return;
        }
        $self->{_raw_reads_fasta_and_qual_writer} = $writer;
    }

    return $self->{_raw_reads_fasta_and_qual_writer};
}

#<TRIM>
sub _trim {
    my ($self, $amplicon, %trimmer_params) = @_;

    my $fasta_file = $self->build->reads_fasta_file_for_amplicon($amplicon);
    next unless -s $fasta_file; # ok

    my $trim3 = Genome::Model::Tools::Fasta::Trim::Trim3->create(
        fasta_file => $fasta_file,
        %trimmer_params,
    );
    unless ( $trim3 ) { # not ok
        $self->error_message("Can't create trim3 command for amplicon: ".$amplicon->name);
        return;
    }
    $trim3->execute; # ok

    next unless -s $fasta_file; # ok

    my $screen = Genome::Model::Tools::Fasta::ScreenVector->create(
        fasta_file => $fasta_file,
    );
    unless ( $screen ) { # not ok
        $self->error_message("Can't create screen vector command for amplicon: ".$amplicon->name);
        return;
    }
    $screen->execute; # ok

    next unless -s $fasta_file; # ok

    my $qual_file = $self->build->reads_qual_file_for_amplicon($amplicon);
    $self->_add_amplicon_reads_fasta_and_qual_to_build_processed_fasta_and_qual(
        $fasta_file, $qual_file
    )
        or return;

    return 1;
}

sub _add_amplicon_reads_fasta_and_qual_to_build_processed_fasta_and_qual {
    my ($self, $fasta_file, $qual_file) = @_;

    # Write the 'raw' read fastas
    my $reader = Genome::Model::Tools::FastQual::PhredReader->create(
        files => [ $fasta_file, $qual_file ],
    );
    return if not $reader;
    while ( my $seqs = $reader->read ) {
        $self->_processed_reads_fasta_and_qual_writer->write($seqs)
            or return;
    }
 
    return 1;
}

sub _processed_reads_fasta_and_qual_writer {
    my $self = shift;

    unless ( $self->{_processed_reads_fasta_and_qual_writer} ) {
        my $fasta_file = $self->build->processed_reads_fasta_file;
        unlink $fasta_file if -e $fasta_file;
        my $qual_file = $self->build->processed_reads_qual_file;
        unlink  $qual_file if -e $qual_file;
        my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file, $qual_file ]);
        return if not $writer;
        $self->{_processed_reads_fasta_and_qual_writer} = $writer;
    }

    return $self->{_processed_reads_fasta_and_qual_writer};
}
#</TRIM>

#<ASSEMBLE>
sub _assemble {
    my ($self, $amplicon, %assembler_params) = @_;

    my $fasta_file = $self->build->reads_fasta_file_for_amplicon($amplicon);
    next unless -s $fasta_file; # ok

    my $phrap = Genome::Model::Tools::PhredPhrap::Fasta->create(
        fasta_file => $fasta_file,
        %assembler_params,
    );
    unless ( $phrap ) { # bad
        $self->error_message(
            "Can't create phred phrap command for build's (".$self->build->id.") amplicon (".$amplicon->{name}.")"
        );
        return;
    }
    $phrap->dump_status_messages(1);
    $phrap->execute; # no check

    return 1;
}
#</ASSEMBLE>

1;

