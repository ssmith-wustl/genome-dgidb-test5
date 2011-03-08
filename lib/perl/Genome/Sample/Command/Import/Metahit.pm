package Genome::Sample::Command::Import::Metahit;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Sample::Command::Import::Metahit { 
    is => 'Genome::Sample::Command::Import',
    has => [
        name => {
            is => 'Text',
            doc => 'MetaHIT sample name.',
        },
        tissue_name => {
            is => 'Text',
            doc => 'Tisse anem from where the sample is from',
        },
        gender => {
            is => 'Text',
            valid_values => [qw/ male female /],
            doc => 'The gender of the individual.',
        },
        age => {
            is => 'Number',
            doc => 'The age of the individual at time of sample taking.',
        },
        bmi => {
            is => 'Text',
            doc => 'The body mass index of the individual at time of sample taking.',
        },
    ],
};

sub execute {
    my $self = shift;

   $self->status_message('Import METAHit Sample...');

    my $taxon = $self->_get_taxon('human');
    Carp::confess('Cannot get human taxon') if not $taxon;

    my $individual_name = 'METAHIT-'.$self->name;
    my $individual = $self->_get_and_update_or_create_individual(
        upn => $individual_name,
        nomenclature => 'METAHIT',
        gender => $self->gender,
        description => 'METAHit individual: unknown source',
    );
    return if not $individual;

    my $name = $individual->name.'-1'; # TODO allow for more than one sample
    my $sample = $self->_get_and_update_or_create_sample(
        name => $name,
        extraction_label => $name,
        source_id => $individual->id,
        source_type => $individual->subject_type,
        tissue_desc => $self->tissue_name,
        tissue_label => $self->tissue_name,
        extraction_type => 'genomic',
        cell_type => 'unknown',
        _nomenclature => 'unknown',
        age => $self->age,
        body_mass_index => $self->bmi,
    );
    return if not $sample;

    my $library = $self->_get_or_create_library_for_extension('extlibs');
    return if not $library;
    $self->_library($library);

    $self->status_message('Import...OK');

    return 1;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2005 - 2010 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

