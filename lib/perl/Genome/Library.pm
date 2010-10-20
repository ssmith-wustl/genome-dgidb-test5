
package Genome::Library; 

# Adaptor for GSC::Organism::Sample

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Library {
    is => ['Genome::Notable'],
    table_name => 'GSC.LIBRARY_SUMMARY',
    id_by => [
        library_id          => { is => 'Number', len => 20 },
    ],
    has => [
        name                => { is => 'Text', len => 64, column_name => 'FULL_NAME' },
    ],
    has_optional => [
        sample_id           => { is => 'Number', len => 20 },
        sample              => { is => 'Genome::Sample', id_by => 'sample_id' },
        sample_name         => { is => 'Text', via => 'sample', to => 'name' },
        taxon_id            => { is => 'Number', via => 'sample', to => 'taxon_id' },
        taxon               => { is => 'Genome::Taxon', id_by => 'taxon_id' },
        species_name        => { via => 'taxon', to => 'species_name' },
        protocol_name       => { is_transient => 1, is => 'Text', },
    ],
    has_many => [
        #solexa_lanes        => { is => 'Genome::InstrumentData::Solexa', reverse_id_by => 'library' },
        #solexa_lane_names   => { via => 'solexa_lanes', to => 'full_name' },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return if not defined $self;

    if ( $self->name ) {
        $self->error_message("Cannot set library name. It is derived from the sample name.");
        $self->delete;
        return;
    }

    if ( not defined $self->sample ) {
        $self->error_message('No sample found for id: '.$self->sample_id);
        $self->delete;
        return;
    }

    my @sample_external_librairies = grep { defined $_->name and $_->name =~ /\-extlib\d+$/ } $self->sample->libraries;
    $self->name($self->sample->name.'-extlib'.(scalar(@sample_external_librairies) + 1));

    return $self;
}

1;

