package Genome::Model::Tools::Annotate::RtPrimerSnps;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Bio::DB::Fasta;


class Genome::Model::Tools::Annotate::RtPrimerSnps {
    is => 'Command',
    has => [
    'snp_file' => {
        type => 'String',
        is_optional => 0,
        doc => 'maq cns2snp output',
    },
    'transcript' => {
        type => 'String',
        is_optional => 0,
        doc => 'transcript name',
    },
    'primer_sequence' => {
        type => 'String',
        is_optional => 0,
        doc => 'sequence of primer to search for snps within',
    },

    ]
};

sub execute {
    my $self = shift;

    unless(-e $self->snp_file) {
        $self->error_message("Input file does not exist");
        return;
    }
    my $build = Genome::Model::ImportedAnnotation->get(name => 'NCBI-human.combined-annotation')->build_by_version(0);
    my $build_id =$build->build_id;

    my $t = Genome::Transcript->get( transcript_name => $self->transcript, build_id => $build_id );
    if($t) {
        print "Found transcript ", $t->transcript_name," on strand ",$t->strand," for gene ", $t->gene_name, "\n";
    }
    else {
        print "Couldn't find specified transcript:",$self->transcript,"\n";
        return;
    }
    my %transcript_coords;

    my @substructures = grep {$_->structure_type eq 'cds_exon' || $_->structure_type eq 'utr_exon'} $t->ordered_sub_structures;


    my $total_substructures = @substructures;
    if($t->strand == -1) {
        @substructures = reverse @substructures; #put in transcript order. I'm not trusting the ordinals here as some are wonky (probably only in introns though)  
    }
    my $current_transcript_position = 1;

    for my $structure (@substructures) {
        if($t->strand == -1) {
            #store starts as appropriate
            $transcript_coords{$current_transcript_position} = $structure->{structure_stop};
        }
        else {
            #must be on + strand
            $transcript_coords{$current_transcript_position} = $structure->{structure_start};
        }
        #reset the offset into the transcript for the next structure start
        #This should be correct for instance with a 1 bp first exon the next start should be 2
        $current_transcript_position += $structure->{structure_stop} - $structure->{structure_start} + 1;
    }

    #at this point the offsets should all be stored
    #now find the primer sequence within the transcript
    my $tseq = $t->cds_full_nucleotide_sequence;
    my $primer_seq = $self->primer_sequence;
    unless($primer_seq =~ /[ACTG]/i) {
        $self->error_message("Primer Sequence can only contain ACTG. Passed $primer_seq");
        return;
    }
    my ($primer_start, $primer_stop) = (0,0); 
    my $found = 0;
    while($tseq =~ /$primer_seq/gi) {
        unless($found) {
            #looking for uncomplemented sequence in transcript
            $primer_stop = pos($tseq);
            $primer_start = $primer_stop - length($primer_seq) + 1;
            print "Found primer from $primer_start to $primer_stop\n";
            print "Primer: $primer_seq\n";
            print "Trscrt: ",substr($tseq, $primer_start-1, $primer_stop - $primer_start + 1 ),"\n";
            $found = 1;
        }
        else {
            $self->error_message("Primer found in multiple places");
            return;
        }
    }
    $primer_seq =~ tr/ACTGactg/TGACtgac/;
    $primer_seq = reverse $primer_seq;
    while($tseq =~ /$primer_seq/gi) {
        #looking for uncomplemented sequence in transcript
        unless($found) {
            $primer_start = pos($tseq);
            $primer_stop = $primer_start - length($primer_seq) + 1;
            print "Found primer from $primer_start to $primer_stop\n";
            print "Primer: $primer_seq\n";
            print "Trscrt: ",substr($tseq, $primer_stop-1, $primer_start - $primer_stop + 1),"\n";
            $found = 1;
            #convert to always be transcript orientation
            ($primer_start, $primer_stop) = ($primer_stop, $primer_start);
        }
        else {
            $self->error_message("Primer found in multiple places");
            return;
        }
    }
    unless($found) {
        print "Couldn't find primer sequence in transcript\n";
        return;
    }

    $DB::single = 1;
    #Do conversion
    #grab any substructures that the primer MIGHT overlap in transcript coordinates
    my @transcript_coords = grep { $_ <= $primer_stop } sort { $a <=> $b } keys %transcript_coords;
    my @genomic_coords = @transcript_coords{@transcript_coords};
    my @primer_genomic_alignments;
    my $current_tcoord = pop @transcript_coords;
    my $current_gcoord = pop @genomic_coords;
    my $current_primer_align_end = $primer_stop;
    while($current_tcoord <= $current_primer_align_end) {
        #convert end to genomic coord
        my $genomic_end;
        my $structure_offset = $current_primer_align_end - $current_tcoord;
        if($t->strand == -1) {
            #offset negative direction from start
            $genomic_end = $current_gcoord - $structure_offset;
        }
        else {
            $genomic_end = $current_gcoord + $structure_offset;
        }

        my $genomic_start = -1;
        if($current_tcoord <= $primer_start) {
            if($t->strand == -1) {
                $genomic_start = $current_gcoord - ($primer_start - $current_tcoord) ;
            }
            else {
                $genomic_start = $primer_start - $current_tcoord + $current_gcoord;
            }
            $current_primer_align_end = -1; #no need to go through the loop again
        }
        else {
            #primer falls across multiple exons
            $current_primer_align_end = $current_tcoord - 1;
            $genomic_start = $current_gcoord;
            $current_tcoord = pop @transcript_coords;
            $current_gcoord = pop @genomic_coords;
        }
        push @primer_genomic_alignments, [$genomic_start, $genomic_end];
    }
    #print converted genomic coordinates
    print "Primer genomic coordinates:\n";
    for my $aligned_block (@primer_genomic_alignments) {
        my ($start, $end) = @$aligned_block;
        print "$start...$end\t";
    }
    print "\n";
    #print retrieved sequence
    my $RefDir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
    my $refdb = Bio::DB::Fasta->new($RefDir);
    print "Sequence for genomic coordinates:\n";
    for my $aligned_block (@primer_genomic_alignments) {
        my ($start, $end) = @$aligned_block;
        my $ref_seq =  $refdb->seq($t->chrom_name, $start => $end); 

        print "$ref_seq\t";
    }
    print "\n";

    #now search the snp file for SNPs
    $self->status_message("Searching for variants within primer location...");
    my $fh = IO::File->new($self->snp_file,"r");
    unless($fh) {
        $self->error_message("Unable to open snp file");
    }
    my $test = $self->is_within_primer($t->chrom_name, @primer_genomic_alignments);
    while(my $line = $fh->getline) {
        my ($chr, $pos) = split /\t/, $line;
        print $line if $test->($chr,$pos);
    }
    return 1;
}

sub is_within_primer {
    my ($self, $chr, @primer_genomic_alignments) = @_;
    my @ordered_genomic_alignments;
    for my $block (@primer_genomic_alignments) {
        my ($start, $stop) = @$block;
        if($start > $stop) {
            ($start, $stop) = ($stop, $start);
        }
        push @ordered_genomic_alignments, [$start, $stop];
    }
    return sub {
        my ($snp_chr, $snp_pos) = @_;
        if($snp_chr eq $chr) {
            for my $block (@ordered_genomic_alignments) {
                my ($start, $stop) = @$block;
                if($snp_pos >= $start && $snp_pos <= $stop) {
                    return 1;
                }
            }
            return;
        }
        else {
            return;
        }
    };
}

1;

sub help_brief {
    return "This module searches for a primer sequence within a transcript and then reports any snps in the snp file that fall within it";
}

