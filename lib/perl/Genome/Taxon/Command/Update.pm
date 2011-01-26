package Genome::Taxon::Command::Update;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Taxon::Command::Update {
    is => 'Genome::Taxon::Command', # ??????
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Taxon' 
        },
#        taxon_id => {
#            is => 'Number',
#            doc => "Genome Taxon id to operate on",
#        }, 
        column => {
            is => 'String',
            doc => "name of column to update",
        },
        value => {
            is => 'String',
            doc => "value to update the column with.",
        },
        #show => { default_value => 'id,species_name,strain_name,ncbi_taxon_id,locus_tag,domain' },
    ],
};

sub sub_command_sort_position { 4 }

sub execute
{
    my $self = shift;
    my $column = $self->column;
    my $value = $self->value;
    my $taxon = Genome::Taxon->get($self->tax_id);
    unless($taxon)
    {
        $self->error_message("no data for taxon id ". $self->tax_id);
        return 0;
    }

    # there are some columns that are 'required'...
    # but they may already be null...
    #$DB::single = 1;

    $taxon->$column($value);
    UR::Context->commit or croak "can't set the value $value for $column";

    return 1;
}

1;

