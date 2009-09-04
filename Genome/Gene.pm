package Genome::Gene;

use strict;
use warnings;

use Genome;

class Genome::Gene {
    type_name => 'genome gene',
    table_name => 'GENE',
    id_by => [
        gene_id => { 
            is => 'Text' 
        },
        species => { is => 'varchar',
            is_optional => 1,
        },
        source => { is => 'VARCHAR',
            is_optional => 1,
        },
        version => { is => 'VARCHAR',
            is_optional => 1,
        },
    ],
    has => [
        hugo_gene_name => { 
            is => 'Text',
            is_optional => 1,
        },
        strand => {
            is => 'Text',
            valid_values => ['+1', '-1', 'UNDEF'],
        },
        data_directory => {
            is => "Path",
        },
    ],
    has_many => [
        transcripts => { 
            calculate_from => [qw/ id data_directory/],
            calculate => q|
                Genome::Transcript->get(gene_id => $id,  data_directory => $data_directory);
            |,
        },
        external_ids => { 
            calculate_from => [qw/ id data_directory/],
            calculate => q|
                Genome::ExternalGeneId->get(gene_id => $id, data_directory => $data_directory);
            |,
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::Genes',
};

sub name
{
    my ($self, $source) = @_;

    my $name = $self->hugo_gene_name;

    return $name if $name;

    my @egis;
    unless ( $source )
    {
        @egis = $self->external_ids;
    }
    elsif ( $source eq "genbank")
    {
        #$egis = $self->external_ids->search({ id_type => 'entrez' });
        @egis = $self->external_ids(id_type => 'entrez');
    }
    else
    {
        #$egis = $self->external_ids->search({ id_type => $source });
        @egis = $self->external_ids(id_type => $source);
    }

    unless ($egis[0]) {
        return '';
    }

    return $egis[0]->id_value;
}


#- EXPRESSIONS -#
sub expressions_by_intensity
{
    my $self = shift;

    # Sort by decrementing intensity
    my @expressions = sort { $b->expression_intensity <=> $a->expression_intensity }
                           $self->expressions;
    return @expressions;
}


1;

