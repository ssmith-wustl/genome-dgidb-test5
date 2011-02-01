package Genome::Sample::Command::Import::Tcga;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Sample::Command::Import::Tcga { 
    is => 'Genome::Sample::Command::Import',
    has => [
        name => {
            is => 'Text',
            doc => 'MetaHIT sample name.',
        },
        _individual_name => { is_optional => 1, },
    ],
    has_optional => [
        extraction_type => {
            is => 'Text',
            default => 'genomic dna',
            doc => 'Extraction type of sample, examples included genomic dna and rna',
        },
    ],
};

sub execute {
    my $self = shift;

    my $individual_name = $self->_validate_name_and_get_individual_name;
    return if not $individual_name;

    my $taxon = $self->_get_taxon('human');
    Carp::confess('Cannot get human taxon') if not $taxon;

    my $individual = $self->_get_and_update_or_create_individual(
        name => $individual_name,
        upn => $individual_name,
        nomenclature => 'unknown',
    );
    return if not $individual;

    my $sample = $self->_get_and_update_or_create_sample(
        name => $self->name,
        extraction_label => $self->name,
        extraction_type => $self->extraction_type,
        cell_type => 'primary',
        _nomenclature => 'TCGA',
    );
    return if not $sample;

    my $library = $self->_get_or_create_library_for_extension('extlibs');
    return if not $library;

    $self->status_message('Import...OK');

    return 1;
}

sub _validate_name_and_get_individual_name {
    my $self = shift;

    my $name = $self->name;
    my @tokens = split('-', $name);
    if ( not @tokens == 7 ) {
        $self->error_message("Invalid TCGA name ($name). It must have 7 parts separated by dashes.");
        return;
    }

    if ( not $tokens[0] eq 'TCGA' ) {
        $self->error_message("Invalid TCGA name ($name). It must start with TCGA.");
        return;
    }

    my $individual_name = join('-', @tokens[0..2]);

    return $individual_name;
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

