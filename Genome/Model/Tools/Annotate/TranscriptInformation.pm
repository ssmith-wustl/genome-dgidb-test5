package Genome::Model::Tools::Annotate::TranscriptInformation;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Annotate::TranscriptInformation {
    is => 'Command',                       
    has => [ 
	transcript => {
	    type  =>  'String',
	    doc   =>  "provide the transcript name",
	},
	make => {
	    type  =>  'String',
	    doc   =>  "provide the organism either mouse or human; default is human",
	    is_optional  => 1,
	},
	trans_pos => {
	    type  =>  'String',
	    doc   =>  "provide a coordinate of interest",
	    is_optional  => 1,
	},
    ], 
};

        

sub help_brief {
    return <<EOS

    gmt annotate transcript-information will print information about and transcript in the lastest version of annotation data in our database

EOS  
}

sub help_synopsis {
    return <<EOS
	gmt annotate transcript-information --transcript NM_001024809
EOS
}

sub help_detail { 
    return <<EOS 

	--trans_pos option will locate the given coordinate in the transcript and print a line of information at the bottom of your screen 
	--make use this option if your transcript is from mouse otherwise, human will be assumed

EOS
}



my ($transcript,$trans_pos,$transcript_info,$strand,$trans_pos_number_line);
sub execute {

    my $self = shift;

    $transcript = $self->transcript;

    my $make = $self->make;
    unless($make) {$make="human";}

    $trans_pos = $self->trans_pos;
    unless ($trans_pos) { $trans_pos = 0; }
     
    &get_transcript_info($make);
    
    &get_transcript;
    
    if ($self->trans_pos) {
	if ($trans_pos_number_line) {
	    print qq(\n$trans_pos_number_line\n);
	} else {
	    print qq(\n$trans_pos was not located\n);
	}
    }
}

sub get_transcript {
    
    my $myCodonTable = Bio::Tools::CodonTable->new();
    my @seq;
    my @fullseq;
    my ($pexon,$pregion,$ppos);
    my $p5=0;
    my $p3=0;
    my ($coding_start,$coding_stop);

    #print qq($transcript $strand\n);
    
    my @positions;
    my $trans_pos_in=0;
    my $trans_pos_in_5utr=0;
    my $trans_pos_in_3utr=0;
    if ($strand eq "+1") {
	foreach my $pos (sort {$a<=>$b} keys %{$transcript_info->{$transcript}}) {
	    push(@positions,$pos);
	}
    } else {
	foreach my $pos (sort {$b<=>$a} keys %{$transcript_info->{$transcript}}) {
	    push(@positions,$pos);
	}
    }

    for my $pos (@positions) {
	my ($exon,$region) = split(/\,/,$transcript_info->{$transcript}->{$pos}->{exon});
	my $frame = $transcript_info->{$transcript}->{$pos}->{frame};
	my $aa_n = $transcript_info->{$transcript}->{$pos}->{aa_n};
	my $base = $transcript_info->{$transcript}->{$pos}->{base};
	
	my ($trans_posid) = $transcript_info->{$transcript}->{$pos}->{trans_pos};
	
	if ($trans_posid) {
	    my ($trans_pos_n,$trans_pos_r)  =  split(/\,/,$trans_posid);
	    $trans_pos_number_line = qq(The position $trans_pos_n was in an $trans_pos_r and is in or after $region $exon, frame $frame, base $base, amino_acid_numuber $aa_n, and falls after $trans_pos_in_5utr bases of 5prime UTR, $trans_pos_in bases of coding sequence and $trans_pos_in_3utr bases of 3prime UTR);
	}

	if ($region =~ /cds/) {
	    $trans_pos_in++;
	    unless ($coding_start) {$coding_start=$pos;}
	    $coding_stop=$pos;
	}
	
	if ($base =~ /\d/) {
	    if ($region =~ /utr/) {
		if ($coding_start) {
		    $p3++;
		    $trans_pos_in_3utr++;
		} else {
		    $p5++;
		    $trans_pos_in_5utr++;
		}
	    }
	} else {
	    push(@seq,$base);
	}
	
	my $range = $transcript_info->{$transcript}->{$pos}->{range};
	my ($r_start,$r_stop) = split(/\-/,$range);
	if ($pos == $r_stop) {
	    if ($region =~ /utr/) {
		if ($coding_start) {
		    print qq($exon $region $range $p3\n);
		    $p3=0;
		} else {
		    print qq($exon $region $range $p5\n);
		    $p5=0;
		}
	    }
	    if ($region =~ /cds/) {
		my $cds = join '' , @seq;
		my $length = length($cds);
		print qq($exon $region $range $length\n$cds\n\n);
		push(@fullseq,$cds);
		undef(@seq);
	    }
	}
    }

    my $sequence = join '' , @fullseq;
    my $protien_seq = $myCodonTable->translate($sequence);
    
    print qq(\n\>$transcript.dna.fasta\n$sequence\n\n\>$transcript.protien.fasta\n$protien_seq\n);
    
}


sub get_transcript_info {

    my ($ensembl_build,$ensembl_data_directory,$genbank_build,$genbank_data_directory,$build_source);

    my ($make) = @_;

    if ($make eq "mouse") {
	$ensembl_build = Genome::Model::ImportedAnnotation->get(name => 'NCBI-mouse.ensembl')->build_by_version("54_37g");
	$ensembl_data_directory = $ensembl_build->annotation_data_directory;
	$genbank_build = Genome::Model::ImportedAnnotation->get(name => 'NCBI-mouse.genbank')->build_by_version("54_37g");
	$genbank_data_directory = $genbank_build->annotation_data_directory;
	$build_source = "Mouse Build version 54_37g";
    } else {
	$ensembl_build = Genome::Model::ImportedAnnotation->get(name => 'NCBI-human.ensembl')->build_by_version("54_36p");
	$ensembl_data_directory = $ensembl_build->annotation_data_directory;
	$genbank_build = Genome::Model::ImportedAnnotation->get(name => 'NCBI-human.genbank')->build_by_version("54_36p");
	$genbank_data_directory = $genbank_build->annotation_data_directory;
	$build_source = "Human Build version 54_36p";
    }

    my $t;
    if ($transcript =~/^ENS/){ #ENST for Human ENSMUST
	($t) = Genome::Transcript->get( transcript_name =>$transcript, data_directory => $ensembl_data_directory);
    }else{
	($t) = Genome::Transcript->get( transcript_name =>$transcript, data_directory => $genbank_data_directory)
    }

    unless ($t) {print qq(\nCould not find a transcript object for $transcript from the $make data warehouse\nWill exit the program now\n\n);;exit(1);}

    my $tseq = $t->cds_full_nucleotide_sequence;
    my @substructures = $t->ordered_sub_structures;
    
    my $total_substructures = @substructures;
    my $t_n = 0; #substructure counter
    
    $strand = $t->strand;
    my $chr = $t->chrom_name;

    my $info;
    $info->{$transcript}->{strand}=$strand;

    my $data_directory = $t->data_directory;
    my $gene_id = $t->gene_id;
    my $source = $t->source;
    my $transcript_status = $t->transcript_status;

    my $gene = $t->gene;
    my $hugo_gene_name = $gene->hugo_gene_name;

    print qq(Hugo gene name $hugo_gene_name, Gene Id $gene_id, Transcript name $transcript, Chromosome $chr, Strand $strand, Transcript status $transcript_status, Transcript source $source $build_source\n\n\n);

    if (@substructures) {
	#print qq($transcript $total_substructures  $strand  $chr $trans_pos\n);

	while ($t_n < $total_substructures) {
	    my $t_region = $substructures[$t_n];
	    $t_n++;
	    
	    my $tr_start = $t_region->{structure_start};
	    my $tr_stop = $t_region->{structure_stop};
	    my $range = "$tr_start\-$tr_stop";
	    my $structure_type = $t_region->{structure_type};

	    #print qq($structure_type $range\n);

	    if ($t_region->{structure_type} =~ /exon/) {
		my $trv_type = $t_region->{structure_type};
		my @nucleotide_array = split(//,$t_region->nucleotide_seq);
		
		my $base_n;
		if ($strand eq "-1") { $base_n=@nucleotide_array; } else {$base_n=-1;}
		
		for my $n ($tr_start..$tr_stop) {
		    
		    my $refbase;
		    if ($t_region->{structure_type} =~ /cds/) {
			if ($strand eq "-1") {$base_n--;} else {$base_n++;}
			$refbase = $nucleotide_array[$base_n];
		    } else {
			$refbase = "$n:$strand";
		    }
		    $info->{$transcript}->{ref_base}->{$n}="$trv_type,$refbase";
		    $info->{$transcript}->{range}->{$n}="$tr_start-$tr_stop";
		    if ($strand eq "-1") {
			$info->{$transcript}->{range}->{$n}="$tr_stop-$tr_start";
		    }
		}
	    }
	}
    } else {
	print qq(\nCould not find substructures in the transcript object for $transcript from the $make data warehouse\nWill exit the program now\n\n);
	exit 1;	
    }
    
    my $exon=0;
    my $previous_coord;
    my $frame=0;
    my $aa_n=1;

    my @positions;
    if ($info->{$transcript}->{strand} eq "-1") {
	foreach my $gcoord (sort {$b<=>$a} keys %{$info->{$transcript}->{ref_base}}) {
	    push(@positions,$gcoord);
	}
    } else {
	foreach my $gcoord (sort {$a<=>$b} keys %{$info->{$transcript}->{ref_base}}) {
	    push(@positions,$gcoord);
	}
    }

    for my $gcoord (@positions) {
	my ($region,$base) = split(/\,/,$info->{$transcript}->{ref_base}->{$gcoord});
	my ($range) = $info->{$transcript}->{range}->{$gcoord};
	
	unless ($previous_coord) {$previous_coord = $gcoord;}

	if ($info->{$transcript}->{strand} eq "-1") {
	    unless ($gcoord + 1 == $previous_coord) {
		$exon++;
	    }
	} else {
	    unless ($gcoord - 1 == $previous_coord) {
		$exon++;
	    }
	}

	if ($region =~ /utr/) {
	    $frame = "-";
	} else {
	    $frame++;
	}
	
	if ($trans_pos == $gcoord) {
	    $transcript_info->{$transcript}->{$gcoord}->{trans_pos}="$trans_pos,$region";
	    #print qq(trans_pos $trans_pos = $gcoord\n);
	} else {
	    if ($info->{$transcript}->{strand} eq "-1") {
		if ($trans_pos < $previous_coord && $trans_pos > $gcoord) {
		    $transcript_info->{$transcript}->{$previous_coord}->{trans_pos}="$trans_pos,intron";
		}
	    } else {
		if ($trans_pos > $previous_coord && $trans_pos < $gcoord) {
		    $transcript_info->{$transcript}->{$previous_coord}->{trans_pos}="$trans_pos,intron";
		}
	    }
	}
	
	$previous_coord = $gcoord;
	$transcript_info->{$transcript}->{$gcoord}->{exon}="$exon,$region";
	$transcript_info->{$transcript}->{$gcoord}->{frame}=$frame;
	$transcript_info->{$transcript}->{$gcoord}->{aa_n}=$aa_n;
	$transcript_info->{$transcript}->{$gcoord}->{base}=$base;
	$transcript_info->{$transcript}->{$gcoord}->{range}=$range;
	
	if ($frame eq "3") {$frame=0;$aa_n++;}
    }
}


sub reverse_complement_allele {
    my ($allele_in) = @_;

    unless ($allele_in =~ /[ACGT]/) { return ($allele_in); }
    my $seq_1 = new Bio::Seq(-seq => $allele_in);
    my $revseq_1 = $seq_1->revcom();
    my $rev1 = $revseq_1->seq;
    
    my $r_base = $rev1;
    
    return $r_base;
}

 
1;



=head1 TITLE

TranscriptInformation

=head1 DESCRIPTION

This script will get transcript information

=head1 Input Options:

transcript
trans_pos
make

=head1 KNOWN BUGS

Please report bugs to <rmeyer@genome.wustl.edu>

=head1 AUTHOR

Rick Meyer <rmeyer@genome.wustl.edu>

=cut
