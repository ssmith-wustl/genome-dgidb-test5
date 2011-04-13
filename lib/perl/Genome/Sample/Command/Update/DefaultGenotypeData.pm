package Genome::Sample::Command::Update::DefaultGenotypeData;

use strict;
use warnings;
use Genome;

class Genome::Sample::Command::Update::DefaultGenotypeData {
    is => 'Genome::Command::Base',
    doc => 'Update the default genotype data for any given sample.',
    has => [
        sample => {
            is => 'Genome::Sample',
            is_many => 0,
            doc => 'Sample for which default genotype data will be set. Resolved by Genome::Command::Base.',
        },
        genotype => {
            is => 'Genome::Site::WUGC::IlluminaGenotyping',
            is_many => 0,
            doc => 'Genotype to use as the default genotype data for sample. Resolved by Genome::Command::Base.',
        },
    ],
};

sub help_detail {
    'Update the default genotype data for any given sample.'
}

sub execute {
    my $self = shift;

    my $sample = $self->sample;
    my $genotype = $self->genotype;

    my $genotype_data = $self->_resolve_genotype_data($genotype);

    $self->status_message('Setting default genotype data to ' . $genotype_data->id . ' for sample ' . $sample->id . '.');
    #$sample->set_defaulte_genotype_data($genotype_data);

    return 1;
}

sub _resolve_genotype_data {
    my $self = shift;
    my $genotype = shift;

    my $seq_id = $genotype->seq_id;

    my $instrument_data = Genome::InstrumentData::Imported->get(
        id => $seq_id,
        import_format => 'genotype file',
    );
    die $self->error_message('No instrument data exists.')
        unless ($instrument_data);

    return $instrument_data;
}

1;
