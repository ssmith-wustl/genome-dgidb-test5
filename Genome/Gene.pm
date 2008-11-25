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
    ],
    has_many => [
        transcripts => { is => 'Genome::Transcript', reverse_id_by => 'gene' },
        external_ids => { is => 'Genome::ExternalGeneId', reverse_id_by => 'gene' },
        gene_expressions => { is => 'Genome::GeneGeneExpression', reverse_id_by => 'gene' },
        expressions => { is => 'Genome::GeneExpression', via => 'gene_expressions', to => 'expression' },
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

