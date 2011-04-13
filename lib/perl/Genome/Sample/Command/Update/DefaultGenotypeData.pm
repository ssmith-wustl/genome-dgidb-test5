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
        overwrite => {
            is => 'Boolean',
            default => 0,
            doc => 'Allow the current default genotype data to be overwrittern.',
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
    
    if ($sample->default_genotype_data && !$self->overwrite) {
        $self->error_message('Default genotype data already specified for sample ' . $sample->__display_name__ . '. Use --overwrite to allow overwriting it.');
        return;
    }

    my $genotype_data = $self->_resolve_genotype_data($genotype);
    unless ($genotype_data) {
        $self->error_message('Unable to find genotype data.');
        return;
    }

    if ($sample->default_genotype_data && $self->overwrite) {
        $self->status_message('Deleting default genotype data for sample ' . $sample->__display_name__ . ' because --overwrite was specified.');
        my $attribute = $sample->attributes(attribute_label => 'default_genotype_data');
        $attribute->delete;
    }
    $self->status_message('Setting default genotype data to ' . $genotype_data->__display_name__ . ' for sample ' . $sample->__display_name__ . '.');
    $sample->set_default_genotype_data($genotype_data);

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

    return $instrument_data;
}

1;
