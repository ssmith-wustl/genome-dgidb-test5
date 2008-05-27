package Genome::DB::Gene;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('gene');
__PACKAGE__->add_columns(qw/ gene_id hugo_gene_name strand /);
__PACKAGE__->set_primary_key('gene_id');
__PACKAGE__->has_many('transcripts', 'Genome::DB::Transcript', 'gene_id');
__PACKAGE__->has_many('external_ids', 'Genome::DB::ExternalGeneId', 'gene_id');
__PACKAGE__->has_many('gene_expressions', 'Genome::DB::GeneGeneExpression', 'gene_id');
__PACKAGE__->many_to_many('expressions', 'gene_expressions', 'expression');

sub name
{
    my ($self, $source) = @_;

    my $name = $self->hugo_gene_name;

    return $name if $name;

    my $egis;
    unless ( $source )
    {
        $egis = $self->external_ids;
    }
    elsif ( $source eq "genbank") 
    {
        $egis = $self->external_ids->search({ id_type => 'entrez' });
    }
    else
    {
        $egis = $self->external_ids->search({ id_type => $source });
    }

    return $egis->first->id_value;
}

#- EXPRESSIONS -#
sub expressions_by_intensity
{
    my $self = shift;

    return $self->expressions->search
    (
        undef,
        { order_by => 'expression_intensity DESC' },
    );
}

1;

#$HeadURL$
#$Id$
