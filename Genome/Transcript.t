#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Storable;
use Test::More tests => 267;

my $build    = Genome::Model::ImportedAnnotation->get(name => 'NCBI-human.combined-annotation')->build_by_version(0);
my $iterator = Genome::Transcript->create_iterator(
    where => [ chrom_name => 1, build_id => $build->build_id ] );

my $storable_data_file = ('/gsc/var/cache/testsuite/data/Genome-Transcript/annot-var-5.stor');

my $sd = retrieve("$storable_data_file");
my %data;

for ( 1 .. 5 )
{
    my $transcript       = $iterator->next;
    my $transcript_id    = $transcript->id;
    my @substructures    = $transcript->sub_structures;
    my $gene             = $transcript->gene;
    my $protein          = $transcript->protein;
    my @gene_expressions = $gene->expressions;
    my @external_ids     = $gene->external_ids;
    $data{$_}{gene} = $gene;
    $data{$_}{substructures} = \@substructures;
    $data{$_}{transcript_id} = $transcript->id;
    $data{$_}{protein} = $protein;
    $data{$_}{gene_expressions} = \@gene_expressions;
    $data{$_}{external_ids}     = \@external_ids;

}

foreach my $key ( 1 .. 5 )
{

    is( $data{$key}{transcript_id},
        $sd->{$key}->{transcript_id},
        'transcript id'
    );
    is( $data{$key}{protein}{protein_id},
        $sd->{$key}->{protein}->{protein_id},
        'protein id'
    );
    is( $data{$key}{protein}{protein_name},
        $sd->{$key}->{protein}->{protein_name},
        'protein name'
    );
    is( $data{$key}{protein}{amino_acid_seq},
        $sd->{$key}->{protein}->{amino_acid_seq},
        'amino acid seq'
    );
    is( $data{$key}{gene}{gene_id},
        $sd->{$key}->{gene}->{gene_id},
        'gene id'
    );
    is( $data{$key}{gene}{hugo_gene_name},
        $sd->{$key}->{gene}->{hugo_gene_name},
        'hugo gene name'
    );

    foreach my $item ( 0 .. $#{ $sd->{$key}->{external_ids} } )
    {
        is( $data{$key}{external_ids}[$item]{external_gene_id},
            $sd->{$key}->{external_ids}->[$item]->{external_gene_id},
            'external gene ids'
        );
    }

    foreach my $item ( 0 .. $#{ $sd->{$key}->{gene_expressions} } )
    {
        is( $data{$key}{gene_expressions}[$item]{gene_expression_id},
            $sd->{$key}->{gene_expressions}->[$item]->{gene_expression_id},
            'gene expressions'
        );

    }

    foreach my $item ( 0 .. $#{ $sd->{$key}->{substructures} } )
    {
        is( $data{$key}{substructures}[$item]{structure_type},
            $sd->{$key}->{substructures}->[$item]->{structure_type},
            'transcript substructure types match'
        );

        is( $data{$key}{substructures}[$item]{structure_start},
            $sd->{$key}->{substructures}->[$item]->{structure_start},
            'transcript substructure starts match'
        );

        is( $data{$key}{substructures}[$item]{structure_end},
            $sd->{$key}->{substructures}->[$item]->{structure_end},
            'transcript substructure ends match'
        );

        is( $data{$key}{substructures}[$item]{ordinal},
            $sd->{$key}->{substructures}->[$item]->{ordinal},
            'transcript substructure ordinal match'
        );
    }

}

# _fin_
