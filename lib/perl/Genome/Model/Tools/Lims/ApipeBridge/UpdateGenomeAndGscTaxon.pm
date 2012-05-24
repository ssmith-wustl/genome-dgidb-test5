package Genome::Model::Tools::Lims::ApipeBridge::UpdateGenomeAndGscTaxon;

use strict;
use warnings;

use Genome;

use Data::Dumper;

class Genome::Model::Tools::Lims::ApipeBridge::UpdateGenomeAndGscTaxon { 
    is => 'Command::V2',
    has => [
        taxon => {
            is => 'Genome::Taxon',
            doc => 'Genome taxon to fix.',
            shell_args_position => 1,
        },
        name => {
            is => 'Text',
            doc => 'The name of the property.',
            valid_values => available_properties(),
            shell_args_position => 2,
        },
        value => {
            is => 'Text',
            doc => 'The value of the property.',
            shell_args_position => 3,
        },
    ],
};

sub help_brief { return 'Fix a taxon in GSC and Genome'; }

sub property_map {
    return (
        estimated_genome_size => 'estimated_organism_genome_size',
        domain => 'domain',
    );
}

sub available_properties {
    my %property_map = property_map();
    return [ keys %property_map ];
}

sub _gsc_name {
    my %property_map = property_map();
    return $property_map{$_[0]->name};
}

sub execute {
    my $self = shift;
    $self->status_message('Fix taxon...');

    my $taxon = $self->taxon;
    if ( not $taxon ) {
        $self->error_message('No taxon given!');
        return;
    }
    $self->status_message('Taxon: '.join(' ', map { $taxon->$_ } (qw/ id name /)));

    my $gsc_taxon = GSC::Organism::Taxon->get(id => $taxon->id);
    if ( not $gsc_taxon ) {
        $self->error_message('Failed to get GSC taxon for id: '.$taxon->id);
        return;
    }
    $self->status_message('GSC Taxon: '.join(' ', map { $taxon->$_ } (qw/ id species_name /)));

    my $name = $self->name;
    my $value = $self->value;
    my $gsc_name = $self->_gsc_name;
    if ( not $gsc_name ) {
        $self->error_message("Unknown property ($name) to update");
        return;
    }

    $self->status_message(
        sprintf(
            "Set genome taxon (%s %s) %s from %s to %s",
            $taxon->name, $taxon->id, $name, ($taxon->$name || 'NULL'), $value,
        )
    );
    $taxon->$name($value) if not defined $taxon->$name or $taxon->$name ne $value;

    $self->status_message(
        sprintf("Set gsc taxon (%s %s) %s from %s to %s\n",
            $gsc_taxon->species_name, $gsc_taxon->id, $gsc_name, ($gsc_taxon->$gsc_name || 'NULL'), $value,
        )
    );
    $gsc_taxon->$gsc_name($value) if not defined $gsc_taxon->$gsc_name or $gsc_taxon->$gsc_name ne $value;

    $self->status_message('Done');
    return 1;
}

1;

