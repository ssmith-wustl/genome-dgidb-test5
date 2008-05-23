package Genome::DB::Transcript;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';
use Genome::DB::Window::TranscriptSubStructure;

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('transcript');
__PACKAGE__->add_columns(qw/ 
    transcript_id
    gene_id
    transcript_start
    transcript_stop
    transcript_name
    source
    transcript_status
    strand
    chrom_id
    /);
__PACKAGE__->set_primary_key('transcript_id');
__PACKAGE__->belongs_to('chromosome', 'Genome::DB::Chromosome', 'chrom_id');
__PACKAGE__->belongs_to('gene', 'Genome::DB::Gene', 'gene_id');
__PACKAGE__->has_many('sub_structures', 'Genome::DB::TranscriptSubStructure', 'transcript_id');
__PACKAGE__->has_one('protein', 'Genome::DB::Protein', 'transcript_id');

#- SUB STRUCTURES -#
sub ordered_sub_structures
{
    my $self = shift;

    return $self->sub_structures->search(undef, { order_by => 'structure_start asc' });
}

sub reverse_ordered_sub_structures
{
    my $self = shift;

    return $self->sub_structures->search(undef, { order_by => 'structure_stop desc' });
}

sub strand_ordered_sub_structures
{
    my $self = shift;

    return $self->sub_structures->search
    (
        undef, 
        { order_by => $self->_strand_order_by_attribute, },
    );
}

sub sub_structures_in_region
{
    my ($self, $start, $stop) = @_;

    $self->fatal_msg("Need a position to get sub structures") unless $start;
    $stop = $start unless defined $stop;
    
    return $self->sub_structures->search
    (
        {
            structure_start => { '<=', $stop, },
            structure_stop => { '>=', $start },
        },
    );
}

sub _strand_order_by_attribute
{
    my $self = shift;

    return ( $self->strand == 1)
    ? 'structure_start asc'
    : 'structure_stop desc';
}

sub sub_structure_window
{
    my ($self, %window_params) = @_;

    my $sub_structure_window = $self->_sub_structure_window;
    return $sub_structure_window if $sub_structure_window; 

    my $sub_structures = $self->ordered_sub_structures;

    return $self->_sub_structure_window
    (
        Genome::DB::Window::TranscriptSubStructure->new
        (
            iterator => $sub_structures,
            %window_params,
        )
    );
}

sub _sub_structure_window
{
    my ($self, $ssw) = @_;

    $self->{_sub_strucuture_window} = $ssw if $ssw;

    return $self->{_sub_strucuture_window};
}

#- GENE -#
sub gene_name
{
    my $self = shift;

    my $gene = $self->gene;
    my $gene_name = $gene->hugo_gene_name; 

    return ( $gene_name )
    ? $gene_name
    : ( $self->source eq "genbank" ) 
    ? $gene->external_ids({ id_type => 'entrez' })->first->id_value
    : $gene->external_ids({ id_type => $self->source })->first->id_value;
}

1;

#$HeadURL$
#$Id$
