package Genome::Taxon::Command::Import;

use strict;
use warnings;

use Genome;

class Genome::Taxon::Command::Import {
    is => 'Command',
    has => [
        domain => {
            is => 'Text',
            len => 255, 
            valid_values => [qw/Bacteria Eukaryota Archaea Virus/],
            doc => 'A name for the taxonomic category.', 
        },
        name => {
            is => 'Text',
            len => 255, 
            doc => 'A name for the taxonomic category (species name, plus strain).', 
        },        
    ],
    has_output => [
        taxon => {  is => 'Genome::Taxon',
                    is_optional => 1, # fix in Command.pm to not require outputs before running
                },
    ],
    doc => 'import a new taxonomic category into the system',
};

sub help_detail {
    return "define new taxonomic categories"
}

sub help_synopsis {
    return 'genome taxonomic category create --name "Example Group Name"';
}

sub execute {
    my $self = shift;
    
    my $obj = Genome::Taxon->create(
        domain => $self->domain,
        name => $self->name, # sets the species_name column, which actually includes both species_name and strain name
    );
    
    unless($obj) {
        $self->error_message('Failed to create model group');
        return;
    }

    $self->taxon($obj);
    
    $self->status_message('Imported new taxon ');
    $self->status_message('ID: ' . $obj->id . ', NAME: ' . $obj->name);
    
    return 1;
}

1;
