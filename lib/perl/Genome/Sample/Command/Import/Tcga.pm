package Genome::Sample::Command::Import::Tcga;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Sample::Command::Import::Tcga { 
    is => 'Genome::Sample::Command::Import::Base',
    has => [
        name => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'TCGA sample name. It must start with TCGA and have 7 parts separated by dashes. Ex: TCGA-00-0000-000-000-0000-00',
        },
        files => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => 'Files that contains patient and sample information. These will be stored in the sample\'s disk allocation.',
        },
        _individual_name => { is_optional => 1, },
        _extraction_type => { is_optional => 1, },
    ],
};

sub help_brief {
    return 'import TCGA samples';
}

sub execute {
    my $self = shift;

    my $validate_and_set = $self->_validate_name_and_set_individual_name_and_extraction_type;
    return if not $validate_and_set;

    my $import = $self->_import(
        taxon => 'human',
        individual => { 
            upn => $self->_individual_name,
            nomenclature => 'TCGA',
            description => 'TCGA individual imported for sample '.$self->name,
        },
        sample => {
            name => $self->name,
            extraction_label => $self->name,
            extraction_type => $self->_extraction_type,
            cell_type => 'unknown',
            nomenclature => 'TCGA',
        },
        library => 'extlibs',
    );
    return if not $import;

    for my $file ( $self->files ) {
        my $add_file = eval{ $self->_sample->add_file($file) };
        if ( not $add_file ) {
            $self->_bail('Failed to add file: '.$file);
            return if not $add_file;
        }
    }

    $self->status_message('Import...OK');

    return 1;
}

sub _validate_name_and_set_individual_name_and_extraction_type {
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

    if ( my @invalid_tokens = grep { $_ !~ /^[\w\d]+$/ } @tokens ) {
        $self->error_message("Found invalid characters in TCGA name. Only letters and numbers are allowed: @invalid_tokens");
        return;
    }
    my $individual_name = join('-', @tokens[0..2]);
    $self->status_message('Individual name: '.$individual_name);
    $self->_individual_name($individual_name);

    my %extraction_types = (
        D => 'genomic dna',
        G => 'ipr product',
        R => 'rna',
        T => 'total rna',
        W => 'ipr product',
        X => 'ipr product',
    );
    my ($extraction_code) = $tokens[4] =~ /(\w)$/;
    if ( not $extraction_code ) {
        $self->error_message('Cannot get extraction code from name part: $tokens[4]');
        return;
    }
    if ( not $extraction_types{$extraction_code} ) {
        $self->error_message("Invalid extraction code ($extraction_code) found in name ($name)");
        return;
    }
    $self->status_message('Extraction type: '.$extraction_types{$extraction_code});
    $self->_extraction_type($extraction_types{$extraction_code});

    return 1
}

1;

