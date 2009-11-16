#REVIEW fdu
#Short: 
#1. remove Genome::Utility::FileSystem from base class list
#2. alignment_params should be better set to handle unprovided (empty) parameters
#by if block testing
#Long:
#1. what is the purpose for these align commands to exist ? Do users really use those 
#as standalone commands for per lane alignment outside of genome model build ? Or codes
#can be moved to Genome::Model::Tools::Align tree
#2. Duplicate parameters/attributes with G::I::Alignment
#3. If the existence of this module validates, implementing multiple
#instrument_data_ids is useful.


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
        trimmer_name                    => {
                                            is => 'Text',
                                            doc => 'the read trimming algorithm to use',
                                        },
        trimmer_version                 => {
                                            is => 'Text',
                                            doc => 'the verstion of the read trimming algorithm to use',
                                        },
        trimmer_params                  => {
                                            is => 'Text',
                                            doc => 'the params to pass to the read trimming algorithm',
                                        },
        force_fragment                  => {
                                            is => 'Boolean', default_value => 0,
                                            doc => 'force paired end instrument data to align as fragment',
                                        },
        picard_version                  => {
                                            is => 'Text',
                                            doc => 'The version of Picard to use for merging files, etc',
                                        },
        samtools_version                => {
                                            is => 'Text',
                                            doc => 'The version of Samtools to use for sam-to-bam, etc',
                                        },

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
    my %alignment_params = (
        instrument_data_id => $self->instrument_data_id,
        reference_name     => $self->reference_name,
        aligner_name       => $self->aligner_name,
        aligner_version    => $self->version,
        aligner_params     => $self->params,
        force_fragment     => $self->force_fragment,
        samtools_verion    => $self->samtools_version,
        picard_version     => $self->picard_version,
    );
    if ($self->trimmer_name) {
        $alignment_params{trimmer_name} = $self->trimmer_name;
        if ($self->trimmer_version) {
            $alignment_params{trimmer_version} = $self->trimmer_version;
        }
        if ($self->trimmer_params) {
            $alignment_params{trimmer_params} = $self->trimmer_params;
        }
    }
    eval {
        $alignment = Genome::InstrumentData::Alignment->create(%alignment_params);
    };
    if (!$alignment || $@) {
        $self->error_message($@);
        $self->error_message('Failed to create an alignment object with params: '. Data::Dumper::Dumper(%alignment_params) );
        return;
    }
    unless ($alignment->find_or_generate_alignment_data) {
        $self->error_message('Failed to find or generate alignment data');
        return;
    }

    return 1;
}


1;

