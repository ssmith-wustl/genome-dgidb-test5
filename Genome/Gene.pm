package Genome::Gene;

use strict;
use warnings;

use Genome;

class Genome::Gene {
    type_name => 'genome gene',
    table_name => 'GENE',
    id_by => [
        gene_id => { is => 'NUMBER' },
    ],
    has => [
        hugo_gene_name => { is => 'String' },
        strand => { is => 'String' },
        build => {
                    is => "Genome::Model::Build",
                    id_by => 'build_id',
        },
    ],
    has_many => [
        transcripts => { 
            calculate_from => [qw/ gene_id build_id/],
            calculate => q|
                Genome::Transcript->get(gene_id => $gene_id,  build_id => $build_id);
            |,
        },
        external_ids => { 
            calculate_from => [qw/ gene_id build_id/],
            calculate => q|
                Genome::ExternalGeneId->get(gene_id => $gene_id, build_id => $build_id);
            |,
        },
        gene_expressions => { 
            calculate_from => [qw/ gene_id build_id/],
            calculate => q|
                Genome::GeneGeneExpression->get(gene_id => $gene_id, build_id => $build_id);
            |,
        },
        expressions => {
            is => 'Genome::GeneExpression', via => 'gene_expressions', to => 'expression'
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

    #return $egis->first->id_value;
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

