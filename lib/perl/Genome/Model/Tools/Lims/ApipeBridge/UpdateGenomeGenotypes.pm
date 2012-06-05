package Genome::Model::Tools::Lims::ApipeBridge::UpdateGenomeGenotypes;

use strict;
use warnings;

class Genome::Model::Tools::Lims::ApipeBridge::UpdateGenomeGenotypes {
    is => 'Command::V2',
    has => [
        genotype_ids => {
            is => 'Text',
            is_many => 1,
            shell_args_position => 1,
            doc => 'The id of the genotype to update.',
        },
    ],
};

sub help_brief { return 'Update APIPE genotype instrument data from LIMS'; }
sub help_detail { return help_brief(); }

sub execute {
    my $self = shift;
    $self->status_message('Updage genome genotype instrument data...');

    my ($attempted, $success) = (qw/ 0 0 /);
    for my $genotype_id ( $self->genotype_ids ) {
        $attempted++;
        $success++ if $self->_update_genotype($genotype_id);
    }

    $self->status_message('Attempted: '.$attempted);
    $self->status_message('Success: '.$success);
    $self->status_message('Done');
    return 1;
}

sub _update_genotype {
    my ($self, $genotype_id) = @_;

    my $instrument_data = Genome::InstrumentData->get($genotype_id);
    if ( not $instrument_data ) {
        $self->status_message('No inst data for id! '.$genotype_id);
        return;
    }

    my $genotype;
    GET_GSC_GENTOYPE: for my $genotype_class (qw/ GSC::Genotyping::External GSC::Genotyping::Internal::Illumina /) { 
        $genotype = $genotype_class->get($genotype_id);
        last GET_GSC_GENTOYPE if $genotype;
    }
    if ( not $genotype) {
        $self->error_message("No genotype for id! $genotype_id");
        return;
    }

    my $platform = $genotype->get_platform;
    if ( not $platform ) {
        $self->error_message('No platform for genotype! '.$genotype_id);
        return;
    }

    my $chip_attribute = $instrument_data->attributes(attribute_label => 'chip_name');
    if ( not $chip_attribute ) {
        $self->status_message( join(' ', $instrument_data->id, 'chip-name-create', $platform->chip_type) );
        $chip_attribute = $instrument_data->add_attribute(attribute_label => 'chip_name', attribute_value => $platform->chip_type);
    }
    elsif ( $chip_attribute->attribute_value ne $platform->chip_type ) {
        $self->status_message( join(' ', $instrument_data->id, 'chip-name-update', $platform->chip_type) );
        $chip_attribute->delete;
        $chip_attribute = $instrument_data->add_attribute(attribute_label => 'chip_name', attribute_value => $platform->chip_type);
    }
    else {
        $self->status_message( join(' ', $instrument_data->id, 'chip-name-ok', $platform->chip_type) );
    }
    die 'Failed to add attribute for chip_name!' if not $chip_attribute or $chip_attribute->attribute_value ne $platform->chip_type;

    my $version_attribute = $instrument_data->attributes(attribute_label => 'version');
    if ( not $version_attribute ) {
        $self->status_message( join(' ', $instrument_data->id, 'version-create', $platform->version) );
        $version_attribute = $instrument_data->add_attribute(attribute_label => 'version', attribute_value => $platform->version);
    }
    elsif ( $version_attribute->attribute_value ne $platform->version ) {
        $self->status_message( join(' ', $instrument_data->id, 'version-update', $platform->version) );
        $version_attribute->delete;
        $version_attribute = $instrument_data->add_attribute(attribute_label => 'version', attribute_value => $platform->version);
    }
    else {
        $self->status_message( join(' ', $instrument_data->id, 'version-ok', $platform->version) );
    }
    if ( not $version_attribute or $version_attribute->attribute_value ne $platform->version ) {
        $self->error_message('Failed to add attribute for version! '.$genotype_id);
        return;
    }

    return 1;
}

1;

