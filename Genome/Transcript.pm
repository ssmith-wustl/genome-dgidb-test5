package Genome::Transcript;

use strict;
use warnings;

use Genome;

class Genome::Transcript {
    type_name => 'genome transcript',
    table_name => 'TRANSCRIPT',
    id_by => [
        chrom_name => { 
            is => 'Text', 
            len => 10 
        },
        transcript_start => { 
            is => 'NUMBER', 
            len => 10, 
            is_optional => 1 },
        transcript_id => { 
            is => 'NUMBER', 
            len => 10 
        },
    ],
    has => [
        gene_id => { 
            is => 'NUMBER', 
            len => 10 
        },
        transcript_stop => { 
            is => 'NUMBER', 
            len => 10, 
            is_optional => 1,
        },
        transcript_name => { 
            is => 'VARCHAR', 
            len => 255, 
            is_optional => 1,
        },
        source => { is => 'VARCHAR',
            len => 7,
            is_optional => 1,
        },
        transcript_status => { is => 'VARCHAR',
            len => 11,
            is_optional => 1,
            valid_values => ['reviewed', 'unknown', 'model', 'validated', 'predicted', 'inferred', 'provisional', 'unknown', 'known', 'novel'],
        },
        strand => { is => 'VARCHAR',
            is_optional => 1,
            valid_values => ['+1', '-1', 'UNDEF'],
        },
        sub_structures => { 
            calculate_from => [qw/ id  data_directory/],
            calculate => q|
            Genome::TranscriptSubStructure->get(transcript_id => $id, data_directory => $data_directory);
            |,
        },
        protein => { 
            calculate_from => [qw/ id data_directory/],
            calculate => q|
            Genome::Protein->get(transcript_id => $id, data_directory => $data_directory);
            |,
        },
        gene => {
            calculate_from => [qw/ gene_id data_directory/],
            calculate => q|
            Genome::Gene->get(gene_id => $gene_id, data_directory => $data_directory);
            |,
        },
        data_directory => {
            is => "Path",
        },

    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::Transcripts',
};

sub transcript_start{
    my $self = shift;
    my $start = $self->__transcript_start;
    return $start if $start;
    $self->status_message("undefined start for transcript (chrom\tstart\tid):(". $self->id.") ".$self->transcript_name.".  Returning -100000 to avoid annotation");
    return -100000;
}

sub transcript_stop{
    my $self = shift;
    my $stop = $self->__transcript_stop;
    return $stop if $stop;
    $self->status_message("undefined stop for transcript (chrom\tstart\tid):(". $self->id.") ".$self->transcript_name.".  Returning -100000 to avoid annotation");
    return -100000;
}

sub rename_to_errors_later{  #TODO Not sure what the new valid method is
    my $self = shift;
    ########TODO check for:
    #phase completeness for cds exons
    #correct bp length for cds exons (length % 3 = 0 for reg, length % 3 = 2 for MT)
    #contiguous substructures
    #flank sequences
    #flank ordinality
    #substructure ordinality
    #substructure presence
    #field completeness
    #always valid(except for field completeness and ordinality) just change status to unknown
    #gene strand same as transcript strand
    #protein seq matches cds exon translation
    return 1;
}


sub structure_at_position {
    my ($self, $position) = @_;

    # check if in range of the trascript
    my @structures = $self->ordered_sub_structures;
    unless (@structures){
        $self->status_message("No sub-structures for transcript (chrom\tstart\tid):(". $self->id.") ".$self->transcript_name);
        return;
    }
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

sub ordered_sub_structures {
    my $self = shift;

    unless (exists $self->{'_ordered_sub_structures'}) {

        my @subs = sort { $a->structure_start <=> $b->structure_start } $self->sub_structures;
        $self->{'_ordered_sub_structures'} = \@subs;
    }
    return @{$self->{'_ordered_sub_structures'}};
}

sub substructures_are_contiguous {
    my $self = shift;
    my @ss = $self->ordered_sub_structures;
    my $stop_position;
    my $last_ss_type;
    while (my $ss = shift @ss){
        if ($stop_position){
            return 0 unless $ss->structure_start == $stop_position + 1;
            $stop_position = $ss->structure_stop;
        }else{
            $stop_position = $ss->structure_stop;
        }
    }
    return 1;
}

#- CDS EXONS -#

sub cds_exons {
    my $self = shift;

    my @ex = grep { $_->structure_type eq 'cds_exon' } $self->ordered_sub_structures;
    return @ex;
}

sub introns {
    my $self = shift;

    my @int = grep { $_->structure_type eq 'intron' } $self->ordered_sub_structures;
    return @int;
}


sub cds_exon_range {
    my $self = shift;

    my @cds_exons = $self->cds_exons
        or return;

    return ($cds_exons[0]->structure_start, $cds_exons[$#cds_exons]->structure_stop);
}

sub length_of_cds_exons_before_structure_at_position { #TODO, clean this up, shouldn't take strand should use transcript strand and exon ordinality
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

sub cds_full_nucleotide_sequence{
    my $self = shift;
    my $seq;
    foreach my $cds_exon ( sort { $a->ordinal <=> $b->ordinal} $self->cds_exons ) {
        $seq.= $cds_exon->nucleotide_seq;
    }
    return $seq;
}


#- GENE -#
sub gene_name
{
    my $self = shift;

    my $gene = $self->gene;
    my $gene_name = $gene->name($self->source);;

    return $gene_name;
}

1;

#TODO
=pod


=cut

