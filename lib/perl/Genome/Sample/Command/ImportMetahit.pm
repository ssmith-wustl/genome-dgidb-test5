package Genome::Sample::Command::ImportMetahit;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Sample::Command::ImportMetahit { 
    is => 'Command',
    has => [
        name => {
            is => 'Text',
            doc => 'MetaHIT sample name.',
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
        _individual_name => {
            calculate_from => [qw/ name /],
            calculate => q| return 'METAHIT-'.$name; |,
        },
    ],
};

sub execute {
    my $self = shift;

    my $individual = $self->_get_or_create_individual;
    return if not $individual;

    my $sample = $self->_get_or_create_sample($individual);
    return if not $sample;

    my $library = $self->_get_or_create_library($sample);
    return if not $library;

    $self->status_message('Import MetaHIT '.$self->name.'...OK');

    return 1;
}

sub _get_or_create_individual {
    my $self = shift;

    my $name = $self->_individual_name;

    $self->status_message('Get or create individual');
    $self->status_message('Individual name: '.$name);

    my $individual = Genome::Individual->get(name => $name);
    if ( $individual ) {
        $self->status_message('Got individual: '.$individual->__display_name__);
        return $individual;
    }

    my $taxon = Genome::Taxon->get(name => 'human');
    Carp::confess('Cannot get human taxon') if not $taxon;

    $individual = Genome::Individual->create(
        name => $name,
        upn => $name,
        taxon_id => $taxon->id,
        _nomenclature => 'unknown',
        gender => $self->gender,
    );
    if ( not $individual ) {
        $self->error_message('Cannot create individual to import MetaHIT '.$self->name);
        return;
    }
    if ( not UR::Context->commit ) {
        $self->error_message('Cannot commit individual to DB.');
        return;
    }

    $self->status_message('Created individual: '.$individual->__display_name__);

    return $individual;
}

sub _get_or_create_sample {
    my ($self, $individual) = @_;

    Carp::confess('No individual given to create sample') if not $individual;

    my $name = $individual->name.'-1'; # TODO allow for more than one sample
    $self->status_message('Get or create sample');
    $self->status_message('Sample name: '.$name);

    my $sample = Genome::Sample->get(name => $name);
    if ( $sample ) {
        $self->status_message('Got sample: '.$sample->name.' ('.$sample->id.')');
        return $sample;
    }

    $sample = Genome::Sample->create(
        name => $name,
        extraction_label => $name,
        source_id => $individual->id,
        source_type => $individual->subject_type,
        tissue_desc => 'G_DNA_Stool',
        tissue_label => 'G_DNA_Stool',
        extraction_type => 'genomic',
        cell_type => 'unknown',
        _nomenclature => 'unknown',
        #age => $self->age,
        #body_mass_index => $self->bmi,
    );
    if ( not $sample ) {
        $self->error_message("Cannot create sample to import MetaHIT $name");
        return;
    }
    if ( not UR::Context->commit ) {
        $self->error_message('Cannot commit sample to DB.');
        return;
    }

    $sample->age( $self->age );
    $sample->body_mass_index( $self->bmi );
    if ( not UR::Context->commit ) {
        $self->error_message('Cannot commit age and bmi to sample in DB.');
        return;
    }

    $self->status_message('Created sample: '.$sample->name.' ('.$sample->id.')');

    return $sample;
}

sub _get_or_create_library {
    my ($self, $sample) = @_;

    Carp::confess('No sample given to create library') if not $sample;

    my $name = $sample->name.'-extlibs';
    $self->status_message('Get or create library');
    $self->status_message('Library name: '.$name);

    my $library = Genome::Library->get(name => $name);
    if ( $library ) {
        $self->status_message('Got library: '.$library->__display_name__);
        return $library;
    }

    $library = Genome::Library->create(
        name => $name,
        sample_id => $sample->id,
    );
    if ( not $library ) {
        $self->error_message("Cannot create library to import MetaHIT $name");
        return;
    }
    if ( not UR::Context->commit ) {
        $self->error_message('Cannot commit library to DB.');
        return;
    }

    $self->status_message('Created library: '.$library->__display_name__);

    return $library;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2005 - 2010 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$

