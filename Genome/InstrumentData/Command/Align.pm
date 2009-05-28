
package Genome::InstrumentData::Command::Align;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Align {
    is => ['Command','Genome::Utility::FileSystem'],
    has_abstract_constant => [
        aligner_name                    => { is => 'Text' },
    ],
    has_input => [
        instrument_data                 => {
                                            is => 'Genome::InstrumentData',
                                            id_by => 'instrument_data_id'
                                        },
        instrument_data_id              => {
                                            is => 'Number',
                                            doc => 'the local database id of the instrument data (reads) to align'
                                        },
    ],
    has_optional_param => [
        reference_build                 => {
                                            is => 'Genome::Model::Build::ReferencePlaceholder',
                                            id_by => 'reference_name',
                                        },
        reference_name                  => {
                                            doc => 'the reference to use by EXACT name, defaults to NCBI-human-build36',
                                            default_value => 'NCBI-human-build36'
                                        },
        version                         => {
                                            is => 'Text', default_value => '0.7.1',
                                            doc => 'the version of maq to use, i.e. 0.6.8, 0.7.1, etc.'
                                        },
        params                          => {
                                            is => 'Text', default_value => '', 
                                            doc => 'any additional params for the aligner in a single string'
                                        },
        force_fragment                  => {
                                            is => 'Boolean', default_value => 0,
                                            doc => 'force paired end instrument data to align as fragment',
                                        }
    ],
    doc => 'align instrument data using one of the available aligners',
};


sub help_synopsis {
return <<EOS
genome instrument-data align maq        -r NCBI-human-build36 -i 2761701954 -v 0.6.5

genome instrument-data align novoalign  -r NCBI-human-build36 -i 2761701954 -v 2.03.12

genome instrument-data align maq -r NCBI-human-build36 -i 2761701954

genome instrument-data align maq --reference-name NCBI-human-build36 --instrument-data-id 2761701954 --version 0.6.5

genome instrument-data align maq -i 2761701954 -v 0.6.5
EOS
}

sub help_detail {
return <<EOS
Launch one of the integrated aligners against identified instrument data.
EOS
}


sub execute {
    my $self = shift;

    my $alignment;
    eval {
       $alignment = Genome::InstrumentData::Alignment->create(
                                                  instrument_data_id => $self->instrument_data_id,
                                                  reference_name => $self->reference_name,
                                                  aligner_name => $self->aligner_name,
                                                  aligner_version => $self->version,
                                                  aligner_params => $self->params,
                                                  force_fragment => $self->force_fragment,
                                              );
    };
    if (!$alignment || $@) {
        $self->error_message($@);
        $self->error_message('Failed to create an alignment object');
        return;
    }
    unless ($alignment->find_or_generate_alignment_data) {
        $self->error_message('Failed to find or generate alignment data');
        return;
    }

    return 1;
}


1;

