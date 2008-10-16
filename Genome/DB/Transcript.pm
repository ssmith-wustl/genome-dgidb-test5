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

sub structure_at_position {
    my ($self, $position) = @_;

    # check if in range of the trascript
    my @structures = $self->ordered_sub_structures;
    return unless $structures[0]->structure_start <= $position
        and $structures[$#structures]->structure_stop >= $position;
 
    # get the sub structure
    for my $struct ( @structures ) {
        return $struct if $position >= $struct->structure_start 
            and $position <= $struct->structure_stop;
    }

    return;
}

sub structures_flanking_structure_at_position {
    my ($self, $position) = @_;

    # check if in range of the trascript
    my @structures = $self->ordered_sub_structures;
    return unless $structures[0]->structure_start <= $position
        and $structures[$#structures]->structure_stop >= $position;
    
    my $structure_index = 0;
    for my $struct ( @structures ) {
        last if $position >= $struct->structure_start 
            and $position <= $struct->structure_stop;
        $structure_index++;
    }
    
    return ( $structure_index == 0 ) # don't return [-1], last struct!
    ? (undef, $structures[1])
    : ( 
        $structures[ $structure_index - 1 ], 
        $structures[ $structure_index + 1 ],
    );
}

#- CDS EXONS -#
sub cds_exons {
    my $self = shift;

    return grep { $_->structure_type eq 'cds_exon' } $self->sub_structures->all;
}

sub cds_exon_range {
    my $self = shift;

    my @cds_exons = $self->cds_exons
        or return;

    return ($cds_exons[0]->structure_start, $cds_exons[$#cds_exons]->structure_stop);
}

sub length_of_cds_exons_before_structure_at_position {
    my ($self, $position, $strand) = @_;

    my @cds_exons = $self->cds_exons
        or return;

    my $structure = $self->structure_at_position($position);
    $strand = '+1' unless $strand;

    # Make this an anon sub for slight speed increase
    my $exon_is_before;
    if ( $strand eq '+1' ) {
        my $structure_start = $structure->structure_start;
        $exon_is_before = sub {
            return $_[0]->structure_stop < $structure_start;
        }
    }
    else {
        my $structure_stop = $structure->structure_stop;
        $exon_is_before = sub {
            return $_[0]->structure_start > $structure_stop;
        }
    }

    my $length = 0;
    foreach my $cds_exon ( @cds_exons ) {
        next unless $exon_is_before->($cds_exon);
        $length += $cds_exon->structure_stop - $cds_exon->structure_start + 1;
    }

    return $length;
}

sub cds_exon_with_ordinal {
    my ($self, $ordinal) = @_;

    foreach my $cds_exon ( $self->cds_exons ) {
        return $cds_exon if $cds_exon->ordinal == $ordinal;
    }

    return;
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
