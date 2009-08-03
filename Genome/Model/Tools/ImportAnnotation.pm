package Genome::Model::Tools::ImportAnnotation;

use strict;
use warnings;

use Genome;            

my $low=500000;
my $high=750000;
UR::Context->object_cache_size_highwater($high);
UR::Context->object_cache_size_lowwater($low);

class Genome::Model::Tools::ImportAnnotation {
    is => 'Command',
    has => [ 
    version => {  #TODO, this can probably be derived from build. species is going to be the same way
        is  => 'Text',
        doc => "Version to use",
    },
    data_directory => {
        is => 'Path',
        doc => "ImportedAnnotation destination build",
    },
    species => {
        is => 'Text',
        doc => 'Species of annotation to import (mouse, human currently suported)',
        valid_values => [qw(mouse human)],
    },
    ],
};

sub sub_command_sort_position { 15 }

sub help_brief {
    'Tools for importing/downloading various annotation external sets.'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools import-annotation ...
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}

sub execute{
    my $self = shift;
    $self->import_objects_from_external_db;

    return 1;
}

sub assign_ordinality{
    my ($self, $strand, $ss_array) = @_;
    my @a;
    if ($strand eq '+1'){
        @a = sort {$a->structure_start <=> $b->structure_start} @$ss_array;
    }else{
        @a =  sort {$b->structure_start <=> $a->structure_start} @$ss_array;
    }
    my $ord = 1;
    for my $ss (@a){
        $ss->ordinal($ord);
        $ord++;
    }
    return 1;
}

sub assign_ordinality_to_exons{
    my ($self, $strand, $ss_array) = @_;
    my @a;
    if ($strand eq '+1'){
        @a = sort {$a->structure_start <=> $b->structure_start} @$ss_array;
    }else{
        @a =  sort {$b->structure_start <=> $a->structure_start} @$ss_array;
    }
    my $ord = 1;
    my $last_exon;
    for my $ss (@a){
        unless ($last_exon){
            $ss->ordinal($ord);
            $last_exon = $ss;
            next;
        }
        $ord++ unless $self->substructures_are_contiguous($strand, $last_exon, $ss);
        $ss->ordinal($ord);
        $last_exon = $ss;
    }
    return 1;
}

sub substructures_are_contiguous{
    my ($self, $strand, $a, $b) = @_;
    if ($strand eq '+1'){
        if ($a->structure_stop >= $b->structure_start){
            $self->warning_message('exons overlap!');
            return undef;
        }
        if ($a->structure_stop+1 == $b->structure_start){
            return 1;
        }

    }elsif($strand eq '-1'){
        if ($b->structure_stop >= $a->structure_start){
            $self->warning_message('exons overlap!');
            return undef;
        }
        if ($b->structure_stop+1 == $a->structure_start){
            return 1;
        }
    }
}

sub assign_phase{
    my ($self, $cds_array) = @_;

    my @a = sort {$a->ordinal <=> $b->ordinal} @$cds_array;

    my $phase = 0;

    my $previous_exon = shift @a;
    $previous_exon->phase($phase);

    for my $cds_exon (@a){
        $phase = ( $phase + $previous_exon->length ) % 3;
        $cds_exon->phase($phase);
        $previous_exon = $cds_exon;
    }

    return 1;
}

sub create_flanking_sub_structures_and_introns{
    my ($self, $transcript, $tss_id_ref, $ss_array) = @_;
    return unless @$ss_array;

    my @a = sort {$a->structure_start <=> $b->structure_start} @$ss_array;

    my $left_flank_structure_stop = $a[0]->structure_start - 1;
    my $left_flank_structure_start = $a[0]->structure_start - 50000;
    my $left_flank = Genome::TranscriptSubStructure->create(
        transcript_structure_id => $$tss_id_ref,
        transcript => $transcript,
        structure_type => 'flank',
        structure_start => $left_flank_structure_start,
        structure_stop => $left_flank_structure_stop,
        data_directory => $self->data_directory,
    );
    $$tss_id_ref++;

    my $right_flank_structure_start = $a[-1]->structure_stop + 1;
    my $right_flank_structure_stop = $a[-1]->structure_start + 50000;
    my $right_flank = Genome::TranscriptSubStructure->create(
        transcript_structure_id => $$tss_id_ref,
        transcript => $transcript,
        structure_type => 'flank',
        structure_start => $right_flank_structure_start,
        structure_stop => $right_flank_structure_stop,
        data_directory => $self->data_directory,
    );
    $$tss_id_ref++;

    $self->assign_ordinality($transcript->strand, [$left_flank, $right_flank]);

    #now create introns for any gaps between exons
    my @introns;
    my $left_ss;
    for my $ss (@a){
        unless ($left_ss){
            $left_ss = $ss;
            next;
        }
        my $right_structure_start = $ss->structure_start;
        my $left_structure_stop = $left_ss->structure_stop;

        if ( $right_structure_start > $left_structure_stop + 1 ){
            my $intron_start = $left_structure_stop+1;
            my $intron_stop = $right_structure_start-1;
            my $intron = Genome::TranscriptSubStructure->create(
                transcript_structure_id => $$tss_id_ref,
                transcript => $transcript,
                structure_type => 'intron',
                structure_start => $intron_start,
                structure_stop => $intron_stop,
                data_directory => $self->data_directory,
            );
            $$tss_id_ref++;
            push @introns, $intron
        }
        $left_ss = $ss;
    }
    $self->assign_ordinality($transcript->strand, \@introns);
    return ($left_flank, $right_flank, @introns);
}

1;

=cut
IMPORT ANNOTATION
This module imports gene, transcript, transcriptsubstructure, and protein data from and external database(currently supporting ensembl and genbank), and imports in into a file based data structure for variant annotation.

pseudocode for importation process

foreach external transcript
    instantiate Genome::Transcript
    grab external gene
    find or create Genome::Gene (genes have multiple transcripts so we will encounter repeats)
    find or create external gene ids (this is the locus link, entrez what have you, won't always be defined)
    grab external substructures
    translate external substructures in Genome::Substures(flank, utr exon, cds exon, intron)
    grab external protein
    if no external protein
        ok if transcript has no cds exon
        create protein if cds exon




=cut

# $Id$
#
