package Genome::Model::Tools::Oligo::RtPcrPrimers;

use strict;
use warnings;
use Genome;
use IPC::Run;

class Genome::Model::Tools::Oligo::RtPcrPrimers {
    is => 'Command',                    
    has => [ # specify the command's properties (parameters) <--- 

	     chromosome => {
		 type  =>  'String',
		 doc   =>  "chromosome ie {1,2,...,22,X,Y}",
	     },
	     target_pos => {
		 type  =>  'Number',
		 doc   =>  "build 36 coordinate of the target to design primers around",
	     },
	     transcript => {
		 type  =>   'String',
		 doc   =>   "The transcript the variation was annotated with",
	         is_optional  => 1,
	     },
	     all_transcripts => {
		 is  =>   'Boolean',
		 doc   =>   "All transcript from annotate-variants will be used",
	         is_optional  => 1,
	     },
	     organism => {
		 type  =>  'String',
		 doc   =>  "provide the organism either mouse or human; default is human",
		 is_optional  => 1,
		 default => 'human',
	     },
	     version => {
		 type  =>  'String',
		 doc   =>  "provide the imported annotation version; default for human is 54_36p and for mouse is 54_37g",
		 is_optional  => 1,
	     },

	],
    
};

sub help_brief {
    return <<EOS
This tool was design to produce a fasta of exonic transcript sequence and run primer3 to design RT-PCR primers around a position of interest.
EOS
}

sub help_synopsis {
    return <<EOS

running...

gmt rt-pcr-primers -chr 15 -target-pos 72102230 

will return three files and you can optionally capture the transcript information which gets printed as std out
human.15.72102230.annotated.list.csv show the info from variant-transcript
chrNM_033238.rtpcr.designseq:742-742.span.742.primer3.result.txt shows the raw primer3 output
chrNM_033238.rtpcr.designseq:742-742.ordered_primer_pairs.txt shows the primer3 primer-pairs with ranking as described by gmt oligo pcr-primers

if the -all-transcripts option is used, individual files for primers foreach transcript will be produced

EOS
}

sub help_detail {
    return <<EOS 

you can enter multiple transcripts however, each should be on the same chromosome and include the target_pos. If no transcripts are provided a list will be generated from the annotator which provides the single preferred transcript by default or all transcripts with the -all-transcripts option.

If the coordinate provide by target-pos falls in an exon, that exon will be omitted from the rt-pcr design sequence. 

EOS
}


sub execute {

    my $self = shift;
    
    my $chromosome = $self->chromosome;
    unless ($chromosome) {$self->error_message("please provide the chromosome"); return 0;}
    my $target_pos = $self->target_pos;
    unless ($target_pos =~ /^[\d]+$/) {$self->error_message("please provide the Build 36 target_pos coordinate"); return 0; }
    my $organism = $self->organism;

    my $transcripts = $self->transcript;
    my @transcripts;

    my $version = $self->version;
    unless ($version) { if ($organism eq "mouse") { $version = "54_37g"; } else { $version = "54_36p"; } }
    my $references_transcripts = "NCBI-$organism.combined-annotation/$version";

    if ($transcripts) {
	@transcripts = split(/\,/,$transcripts);
    } else {
	my $name = "$organism.$chromosome.$target_pos";
	my $ref_base = &get_ref_base($target_pos,$target_pos,$chromosome,$organism);
	my ($rev) = &reverse_complement_allele ($ref_base);
	
	open(ANNOLIST,">$name.annotation.list") || die "couldn't open a file to write an annotation list\n";
	print ANNOLIST qq($chromosome\t$target_pos\t$target_pos\t$ref_base\t$rev\n);
	close(ANNOLIST);
	
	my $annotation_file = "$name.annotated.list.csv";


	my @command;

	if ($self->all_transcripts) {
	    @command = ["gmt" , "annotate" , "transcript-variants" , "--variant-file" , "$name.annotation.list" , "--output-file" , "$annotation_file" , "--flank-range" , "0" , "--extra-details" , "--annotation-filter" , "none" , "--reference-transcripts" , "$references_transcripts"]; #running it this way will get all transcripts
	} else {
	    @command = ["gmt" , "annotate" , "transcript-variants" , "--variant-file" , "$name.annotation.list" , "--output-file" , "$annotation_file" , "--flank-range" , "0" , "--extra-details" , "--reference-transcripts" , "$references_transcripts"]; #running it this way will get the prefered Genes
	}

	&ipc_run(@command);

	my ($annotation_info) = &parse_annotation($annotation_file);
	
	foreach my $transcripts (sort keys %{$annotation_info}) {
	    push(@transcripts,$transcripts);
	    #$annotation_info->{$transcript}->{gene}=$gene;
	    #$annotation_info->{$transcript}->{transcript}=$transcript;
	    #$annotation_info->{$transcript}->{strand}=$strand;
	    #$annotation_info->{$transcript}->{trv_type}=$trv_type;
	}
    }

    unless (@transcripts) { die "no transcripts were identified\n"; }

    for my $transcript (@transcripts) {
	
	my ($info) = Genome::Model::Tools::Annotate::TranscriptInformation->execute(transcript => "$transcript", trans_pos => "$target_pos", utr_seq => "1", organism => "$organism", version => "$version");
	my $transcript_info = $info->{result};
	my $strand = $transcript_info->{$transcript}->{-1}->{strand};
	#my ($chromosome) = $transcript_info->{$transcript}->{-1}->{source_line} =~ /Chromosome ([\S]+)\,/;
	my ($transcript_seq,$target) = &get_transcript_seq($strand,$transcript,$transcript_info,$organism,$chromosome);
	
	print qq(\n\n$transcript_info->{$transcript}->{-1}->{source_line}\n);
	
	print qq(\n\n\n);
	
	my $exclude_exon = 0;
	
	my $side = "P5";
	my $design_seq;
	my $nn=0;
	
	my $target_depth;
	
	foreach my $n (sort {$a<=>$b} keys %{$transcript_seq}) {
	    
	    my $tp_region = $target->{tp_regoin};
	    
	    if ($tp_region =~ /exon/) {
		$exclude_exon=$target->{exon};
	    }
	    my ($exon,$region) = split(/\,/,$transcript_seq->{$n}->{exon});
	    
	    if ($transcript_seq->{$n}->{trans_pos}) {
		$target_depth = $nn;
		print qq(\n\ntrans_pos $transcript_seq->{$n}->{trans_pos}\n\n);
	    }
	    if ($transcript_seq->{$n-1}->{trans_pos}) {
		print qq(\n\ntrans_pos $transcript_seq->{$n-1}->{trans_pos}\n\n);
	    }
	    
	    if ($tp_region =~ /exon/ && $exclude_exon == $exon) {
		print qq($exon);
	    } else {
		$nn++;
		$design_seq->{$nn}->{base}=$transcript_seq->{$n}->{base};
		
		print qq($transcript_seq->{$n}->{base});
		
	    }
	}
	print qq(\n\n\n);

	my $fasta = "$transcript.rtpcr.designseq.fasta";
	open(FA,">$fasta") || die "couldn't open a fasta file to write to\n";
	print FA qq(\>$transcript.rtpcr.designseq\n);
	foreach my $n (sort {$a<=>$b} keys %{$design_seq}) {
	    my $base = $design_seq->{$n}->{base};
	    print FA qq($base);
	}
	print FA qq(\n);
	close (FA);

	my $hspsepSmax = $target->{seq_stop} - $target->{seq_start} + 51;
	system qq(gmt oligo get-pcr-primers -fasta $fasta -target-depth $target_depth -hspsepSmax $hspsepSmax -organism $organism);
    }
}

sub get_transcript_seq {
    
##########################################
    
    my $nb = 0;

    my ($transcript_seq,$target);

    my ($pause,$resume,$base_count);
    my ($strand,$transcript,$transcript_info,$organism,$chromosome) = @_;
    

    my (@positions);

    if ($strand eq "+1") {
	foreach my $pos (sort {$a<=>$b} keys %{$transcript_info->{$transcript}}) {
	    unless ($pos == -1) {
		push(@positions,$pos);
		unless ($target->{seq_start}) {$target->{seq_start}=$pos;}
		$target->{seq_stop}=$pos;
	    }
	}
    } else {
	foreach my $pos (sort {$b<=>$a} keys %{$transcript_info->{$transcript}}) {
	    unless ($pos == -1) {
		push(@positions,$pos);
		unless ($target->{seq_stop}) {$target->{seq_stop}=$pos;}
		$target->{seq_start}=$pos;
	    }
	}
    }
    
    for my $pos (@positions) {

	my ($exon,$region) = split(/\,/,$transcript_info->{$transcript}->{$pos}->{exon});
	my $frame = $transcript_info->{$transcript}->{$pos}->{frame};
	my $aa_n = $transcript_info->{$transcript}->{$pos}->{aa_n};
	my $base = $transcript_info->{$transcript}->{$pos}->{base};
	my ($trans_pos) = $transcript_info->{$transcript}->{$pos}->{trans_pos};

	my $range = $transcript_info->{$transcript}->{$pos}->{range};
	my ($r_start,$r_stop) = split(/\-/,$range);

	if ($base =~ /(\d+)\:\S/) {
	    my $coord = $1; 
	    $base = &get_utr_seq($coord,$strand,$organism,$chromosome);
	}

	$base_count++;
	$transcript_seq->{$base_count}->{base}=$base;
	$transcript_seq->{$base_count}->{transcript}=$transcript;
	$transcript_seq->{$base_count}->{exon}="$exon,$region";

	$nb++;
	if ($trans_pos) {
	    my ($tp_region) = $trans_pos =~ /\S+\,(\S+)/;
	    $transcript_seq->{$base_count}->{trans_pos}="$exon,$region,$pos,$base_count,$tp_region";
	    $target->{tp_regoin}=$tp_region;
	    $target->{exon}=$exon;
	    $target->{base_count}=$base_count;
	}
    }
    return($transcript_seq,$target);
}

sub get_utr_seq {
    
    my ($pos,$strand,$organism,$chromosome) = @_;
    my $base;
    if ($strand eq "-1") {
	my $seq = &get_ref_base($pos,$pos,$chromosome,$organism);
	my $rev = &reverse_complement_allele($seq);
	$base = $rev;
    } else {
	my $seq = &get_ref_base($pos,$pos,$chromosome,$organism);
	$base = $seq;
    }
    return($base);
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

sub get_ref_base {

    my ($chr_start,$chr_stop,$chr_name,$organism) = @_;
    use Bio::DB::Fasta;
    my $RefDir;
    if ($organism eq "human"){
	$RefDir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
    } else {
	$RefDir = "/gscmnt/sata147/info/medseq/rmeyer/resources/MouseB37/";
    }
    my $refdb = Bio::DB::Fasta->new($RefDir);
    my $seq = $refdb->seq($chr_name, $chr_start => $chr_stop);
    $seq =~ s/([\S]+)/\U$1/;

    return $seq;
}


sub ipc_run {

    my (@command) = @_;

    #my $comand_line = join (' ' , @command);
    #print qq(will now run $comand_line\n);

    my ($in, $out, $err);
    my ($obj) = IPC::Run::run(@command, \$in, \$out, \$err);
    if ($err) {
#	print qq($err\n);
    }
    if ($out) {
	return ($out);
	#print qq($out\n);
    }
}

sub parse_annotation {
    my $annotation_info;
    my ($annotation_file) = @_;
    open(ANO,"$annotation_file") || die "couldn't open the annotation file\n";
    while (<ANO>) {
	chomp;
	my $line = $_;
	my ($chromosome,$start,$stop,$ref,$var,$variant_type,$gene,$transcript,$transcript_species,$source,$tv,$strand,$Traans_stat,$trv_type,$c_pos,$aa,$cons_score,$domain) = split(/[\s]+/,$line); ##get extended annotation
#chromosome_name	start	stop	reference	variant	type	gene_name	transcript_name	transcript_species	transcript_source	transcript_version	strand	transcript_status	trv_type	c_position	amino_acid_change	ucsc_cons	domain	all_domains	flank_annotation_distance_to_transcript	intron_annotation_substructure_ordinal	intron_annotation_substructure_size	intron_annotation_substructure_position

	unless ($chromosome eq "chromosome_name") {
	    my $chr = "chr$chromosome";
	    
	    if ($transcript =~ /\d+/) {
		$annotation_info->{$transcript}->{gene}=$gene;
		$annotation_info->{$transcript}->{transcript}=$transcript;
		$annotation_info->{$transcript}->{strand}=$strand;
		$annotation_info->{$transcript}->{trv_type}=$trv_type;
	    }
	}
    } close (ANNO);
    return($annotation_info);
}

1;


=head1 TITLE

PtPcrPrimers

=head1 DESCRIPTION

This script will produce rt-pcr primers!

=head1 Input Options:

chrmosome coordinate transcript all_transcripts organism version

=head1 KNOWN BUGS

Please report bugs to <rmeyer@genome.wustl.edu>

=head1 AUTHOR

Rick Meyer <rmeyer@genome.wustl.edu>

=cut
