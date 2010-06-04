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
		 is_optional  => 1,
	     },
	     target_pos => {
		 type  =>  'Number',
		 doc   =>  "build 36 coordinate of the target to design primers around",
		 is_optional  => 1,
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
		 doc   =>  "provide the imported annotation version; default for human is 54_36p_v2 and for mouse is 54_37g_v2",
		 is_optional  => 1,
	     },
	     pcr_primer_options => {
		 type  =>  'String',
		 doc   =>  "provide a quoted string of options you'd like to set when running oligo pcr-primers",
		 is_optional  => 1,
	     },
	     include_exon => {
		 is  =>   'Boolean',
		 doc   =>  "if your target_pos falls in an exon, by default that exon will be ommitted from the primer design sequence. Use this flag if you would rather include that exon in the design sequence",
		 is_optional  => 1,
	     },
	     variant_transcript_annotation => {
		 type  =>  'String',
		 doc   =>  "provide the annotation file from \"gmt annotate variant-transcript\" if this option is used, these options should be omitted chromosome target_pos transcript all_transcripts and version",
		 is_optional  => 1,
	     },
	     masked => {
		 is => 'Boolean',
		 doc   =>  "use this option to mask_snps_and_repeats",
		 is_optional  => 1,
	     },
	     screen_snp_list => {
		 is => 'String',
		 doc   =>  "use this option by providing a list of snp to mask your sequence; format file, 1st column chromosome second column coordinate separated by space",
		 is_optional  => 1,
	     },
         output_dir => {
             is => 'String',
             doc => "specify an output directory",
             is_optional => 1,
             default => '.',
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

if the -pcr-primer-options option is used, place the options you select in a quoted string in the same fashion as you would when running pcr-primer eg;
\"-primer-perimeter 125 -product-range 300-500 -gc-clamp 2\"


EOS
}


sub execute {

    my $self = shift;
    
    my $chromosome = $self->chromosome;
    #unless ($chromosome) {$self->error_message("please provide the chromosome"); return 0;}
    my $target_pos = $self->target_pos;
    #unless ($target_pos =~ /^[\d]+$/) {$self->error_message("please provide the Build 36 target_pos coordinate"); return 0; }

    my $variant_transcript_annotation  = $self->variant_transcript_annotation;
    unless (($chromosome && $target_pos) || ($variant_transcript_annotation && -e $variant_transcript_annotation)) {
        $self->error_message("please provide the chromosome and target-pos or the variant-transcript-annotation file"); 
        return 0;
    }

    my $output_dir = $self->output_dir;
    unless (-d $output_dir){
        unless (mkdir $output_dir){
            $self->error_message("Couldn't create output directory: $output_dir ($!)");
            return 0;
        }
    }
    my $organism = $self->organism;
    my $transcripts = $self->transcript;
    my @transcripts;

    my $version = $self->version;
    unless ($version) { if ($organism eq "mouse") { $version = "54_37g_v2"; } else { $version = "54_36p_v2"; } }
    my $references_transcripts = "NCBI-$organism.combined-annotation/$version";

    my $annotation_info;
    if ($transcripts) {
        @transcripts = split(/\,/,$transcripts);

        for my $transcript (@transcripts) {

            my ($ncbi_reference) = $version =~ /\_([\d]+)/;

            my $eianame = "NCBI-" . $organism . ".ensembl";
            my $gianame = "NCBI-" . $organism . ".genbank";
            my $build_source = "$organism build $ncbi_reference version $version";

            my $ensembl_build = Genome::Model::ImportedAnnotation->get(name => $eianame)->build_by_version($version);
            my ($ensembl_data_directory) = $ensembl_build->determine_data_directory;
            my $genbank_build = Genome::Model::ImportedAnnotation->get(name => $gianame)->build_by_version($version);
            my ($genbank_data_directory) = $genbank_build->determine_data_directory;

            my $t;
            if ($transcript =~/^ENS/){ #ENST for Human ENSMUST
                ($t) = Genome::Transcript->get( transcript_name =>$transcript, data_directory => $ensembl_data_directory);
            }else{
                ($t) = Genome::Transcript->get( transcript_name =>$transcript, data_directory => $genbank_data_directory)
            }

            unless ($t) {print qq(\nCould not find a the gene name for $transcript\n);}

            my $gene = $t->gene;
            my $hugo_gene_name = $gene->hugo_gene_name;

            $annotation_info->{$transcript}->{$target_pos}->{transcript}=$transcript;
            $annotation_info->{$transcript}->{$target_pos}->{target_pos}=$target_pos;
            $annotation_info->{$transcript}->{$target_pos}->{chromosome}=$chromosome;
            $annotation_info->{$transcript}->{$target_pos}->{transcript_species}=$organism;
            $annotation_info->{$transcript}->{$target_pos}->{output_name} = "$hugo_gene_name.$transcript.$chromosome.$target_pos";
        }

    } elsif ($variant_transcript_annotation) {

        ($annotation_info) = &parse_annotation($variant_transcript_annotation);
        foreach my $transcripts (sort keys %{$annotation_info}) {
            push(@transcripts,$transcripts);
        }

    } else {
        my $name = "$output_dir/$organism.$chromosome.$target_pos";
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

        ($annotation_info) = &parse_annotation($annotation_file);
        foreach my $transcripts (sort keys %{$annotation_info}) {
            push(@transcripts,$transcripts);
            #$annotation_info->{$transcript}->{gene}=$gene;
            #$annotation_info->{$transcript}->{transcript}=$transcript;
            #$annotation_info->{$transcript}->{strand}=$strand;
            #$annotation_info->{$transcript}->{trv_type}=$trv_type;
        }
    }

    unless (@transcripts) { die "no transcripts were identified\n"; }

    #for my $transcript (@transcripts) {
    foreach my $transcript (sort keys %{$annotation_info}) {
        foreach my $trans_pos (sort {$a<=>$b} keys %{$annotation_info->{$transcript}}) {
            $target_pos=$trans_pos;
            
            my $output_name = $annotation_info->{$transcript}->{$trans_pos}->{output_name};
            unless ($chromosome) {$chromosome = $annotation_info->{$transcript}->{$trans_pos}->{chromosome};}

            #my ($info) = Genome::Model::Tools::Annotate::TranscriptInformation->execute(transcript => "$transcript", trans_pos => "$target_pos", utr_seq => "1", organism => "$organism", version => "$version", output => "$output_name");
            my $info;
            if ($self->masked) {
                ($info) = Genome::Model::Tools::Annotate::TranscriptSequence->execute(transcript => "$transcript", trans_pos => "$target_pos", utr_seq => "1", organism => "$organism", version => "$version", output => "$output_dir/$output_name", masked => "1", no_stdout => "1");
            } else {
                ($info) = Genome::Model::Tools::Annotate::TranscriptSequence->execute(transcript => "$transcript", trans_pos => "$target_pos", utr_seq => "1", organism => "$organism", version => "$version", output => "$output_dir/$output_name", no_stdout => "1");

                #my @command = ["gmt" , "annotate" , "transcript-sequence" , "-transcript" , "$transcript" , "-trans-pos" , "$target_pos" , "-utr-seq" , "-organism" , "$organism" , "-version" , "$version" , "-output" , "$output_name"];
                #($info) = &ipc_run(@command);

            }
            my $transcript_info = $info->{result};
            my $strand = $transcript_info->{$transcript}->{-1}->{strand};
            my $gene = $transcript_info->{$transcript}->{-1}->{hugo_gene_name};
            my $gene_id = $transcript_info->{$transcript}->{-1}->{gene_id};
            #my ($chromosome) = $transcript_info->{$transcript}->{-1}->{source_line} =~ /Chromosome ([\S]+)\,/;
            my ($transcript_seq,$target) = &get_transcript_seq($strand,$transcript,$transcript_info,$organism,$chromosome,$trans_pos,$self);

            print qq(\n\n$transcript_info->{$transcript}->{-1}->{source_line}\n);


            #$transcript_info->{$transcript}->{-1}->{trans_pos_n}=$trans_pos_n;
            #$transcript_info->{$transcript}->{-1}->{trans_pos_r}=$trans_pos_r;
            my $tp_region = $transcript_info->{$transcript}->{-1}->{region};
            my $tp_exon = $transcript_info->{$transcript}->{-1}->{exon};
            #$transcript_info->{$transcript}->{-1}->{frame}=$frame;
            #$transcript_info->{$transcript}->{-1}->{base}=$base;
            #$transcript_info->{$transcript}->{-1}->{aa_n}=$aa_n;
            #$transcript_info->{$transcript}->{-1}->{trans_pos_in_5utr}=$trans_pos_in_5utr;
            #$transcript_info->{$transcript}->{-1}->{trans_pos_in}=$trans_pos_in;
            #$transcript_info->{$transcript}->{-1}->{trans_pos_in_3utr}=$trans_pos_in_3utr;
            #$transcript_info->{$transcript}->{-1}->{trans_posid}=$trans_posid;

            my $trans_posid = $transcript_info->{$transcript}->{-1}->{trans_posid};
            unless ($trans_posid) {$trans_posid = "not_ided";}
            if ($trans_posid eq "not_ided") {
                print qq(Did not Find the coordinate $trans_pos with in the transcript $transcript.\nNo design will be attempted on $transcript targeting $trans_pos.\n);
                next;
            }


            print qq(\n$trans_posid\n\n);

            my $excluded_exon = 0;

            my $side = "P5";
            my $design_seq;
            my $nn=0;

            my $target_depth=0;
            
            open(OUT,">>$output_dir/$output_name.txt") or die "Couldn't open output file: $output_dir/$output_name.txt ($!)";
            print OUT qq(\n\n\n);
            if ($self->masked) {open(TEMP,">Temp.masked.designseq.info.txt");}

            foreach my $n (sort {$a<=>$b} keys %{$transcript_seq}) {

                my $tp_region = $target->{tp_regoin};

                my ($exon,$region) = split(/\,/,$transcript_seq->{$n}->{exon});

                if ($tp_region =~ /exon/) {
                    unless ($self->include_exon || $exon eq "1" || $target->{last_exon} eq $target->{exon}) {
                        $excluded_exon=$target->{exon};
                    }
                }

                if ($transcript_seq->{$n}->{trans_pos}) {
                    $target_depth = $nn;
                    #print qq(\n\ntrans_pos $transcript_seq->{$n}->{trans_pos}\n\n);
                    print OUT qq(\n\ntrans_pos $transcript_seq->{$n}->{trans_pos}\n\n);
                    if ($self->masked) {
                        print TEMP qq(\n\ntrans_pos $transcript_seq->{$n}->{trans_pos}\n\n);
                    }
                }
                if ($transcript_seq->{$n-1}->{trans_pos}) {
                    print qq(\n\ntrans_pos $transcript_seq->{$n-1}->{trans_pos}\n\n);
                    print OUT qq(\n\ntrans_pos $transcript_seq->{$n-1}->{trans_pos}\n\n);
                    if ($self->masked) {
                        print TEMP qq(\n\ntrans_pos $transcript_seq->{$n-1}->{trans_pos}\n\n);
                    }
                }

                if ($tp_region =~ /exon/ && $excluded_exon == $exon) {
                    print qq($exon);
                    print OUT qq($exon);
                    if ($self->masked) {print TEMP qq($exon);}
                } else {
                    $nn++;
                    $design_seq->{$nn}->{base}=$transcript_seq->{$n}->{base};

                    print qq($transcript_seq->{$n}->{base});
                    print OUT qq($transcript_seq->{$n}->{base});

                    if ($self->masked) {print TEMP qq($transcript_seq->{$n}->{masked_base});}

                }
            }
            print qq(\n\n\n);
            print OUT qq(\n\n\n);
            close (OUT);
            close (TEMP);
            if ($self->masked) {
                system qq(cat Temp.masked.designseq.info.txt);
                system qq(cat Temp.masked.designseq.info.txt >> $output_dir/$output_name.txt);
                system qq(rm Temp.masked.designseq.info.txt);
            }

            my $fasta = "$output_dir/$output_name.rtpcr.designseq.fasta";
            open(FA,">$fasta") || die "couldn't open a fasta file to write to\n";
            print FA qq(\>$output_dir/$output_name.rtpcr.designseq\n);

            my $fasta_masked;
            if ($self->masked) {
                $fasta_masked = "$output_dir/$output_name.masked.rtpcr.designseq.fasta";
                open(MFA,">$fasta_masked") || die "couldn't open a fasta file to write to\n";
                print MFA qq(\>$output_dir/$output_name.masked.rtpcr.designseq\n);
            }
            foreach my $n (sort {$a<=>$b} keys %{$design_seq}) {
                my $base = $design_seq->{$n}->{base};
                print FA qq($base);
                if ($self->masked) {
                    my $masked_base = $transcript_seq->{$n}->{masked_base};
                    print MFA qq($masked_base);
                }
            }
            print FA qq(\n);
            close (FA);
            if ($self->masked) { print MFA qq(\n); close (MFA); }

            my $note = "$gene\t$strand\t$transcript\t$chromosome\t$trans_pos\t$tp_region\t$tp_exon";
            my $header = "gene\tstrand\ttranscript\tchromosome\ttarget_position\ttarget_position_region\ttarget_position_tp_exon";
            my $hspsepSmax = $target->{seq_stop} - $target->{seq_start} + 51;
            my $pcr_primer_options =  $self->pcr_primer_options;
            #my $blast_db = "/gscmnt/sata147/info/medseq/rmeyer/resources/HS36Transcriptome/new_masked_ccds_ensembl_genbank_utr_nosv_all_transcriptome_quickfix.fa";

            if ($pcr_primer_options) {
                system qq(gmt oligo pcr-primers -output-dir $output_dir -output-name $output_name -fasta $fasta -target-depth $target_depth -hspsepSmax $hspsepSmax -organism $organism $pcr_primer_options -display-blast -note "$note" -header "$header");
                if ($self->masked) {
                    system qq(gmt oligo pcr-primers -output-dir $output_dir -output-name $output_name.masked -fasta $fasta_masked -target-depth $target_depth -hspsepSmax $hspsepSmax -organism $organism $pcr_primer_options -display-blast -note "$note" -header "$header");
                }
            } else {
                system qq(gmt oligo pcr-primers -output-dir $output_dir -output-name $output_name -fasta $fasta -target-depth $target_depth -hspsepSmax $hspsepSmax -organism $organism -display-blast -note "$note" -header "$header");
                if ($self->masked) {
                    system qq(gmt oligo pcr-primers -output-dir $output_dir -output-name $output_name.masked -fasta $fasta_masked -target-depth $target_depth -hspsepSmax $hspsepSmax -organism $organism -display-blast -note "$note" -header "$header");
                }
            }
            print qq(see your transcript information in $output_dir/$output_name.txt\n);
        }
    }
}

sub get_transcript_seq {
    my $nb = 0;
    my ($transcript_seq,$target);
    my ($pause,$resume,$base_count);
    my ($strand,$transcript,$transcript_info,$organism,$chromosome,$target_position,$self) = @_;

    my $screen;
    if ($self->screen_snp_list) {
        ($screen) = get_screen_snp_list ($transcript,$transcript_info,$self);
    }

    
    my (@positions);

    if ($strand eq "+1") {
	foreach my $pos (sort {$a<=>$b} keys %{$transcript_info->{$transcript}}) {
        unless ($pos == -1) {
            push(@positions,$pos);
            unless ($target->{seq_start}) {$target->{seq_start}=$pos;}
            $target->{seq_stop}=$pos;
	    }
	}
    } elsif ($strand eq "-1") {
	foreach my $pos (sort {$b<=>$a} keys %{$transcript_info->{$transcript}}) {
        unless ($pos == -1) {
            push(@positions,$pos);
            unless ($target->{seq_stop}) {$target->{seq_stop}=$pos;}
            $target->{seq_start}=$pos;
	    }
	}
    } else {
	    die "strand not define for transcript $transcript\n";
    }
    
    for my $pos (@positions) {

	my ($exon,$region) = split(/\,/,$transcript_info->{$transcript}->{$pos}->{exon});

	$target->{last_exon} = $exon;

	my $frame = $transcript_info->{$transcript}->{$pos}->{frame};
	my $aa_n = $transcript_info->{$transcript}->{$pos}->{aa_n};
	my $base = $transcript_info->{$transcript}->{$pos}->{base};
	my $masked_base = $transcript_info->{$transcript}->{$pos}->{masked_base};
	my $trans_pos = $transcript_info->{$transcript}->{$pos}->{trans_pos};

	my $range = $transcript_info->{$transcript}->{$pos}->{range};
	my ($r_start,$r_stop) = split(/\-/,$range);

	if ($base =~ /(\d+)\:\S/) {
	    my $coord = $1; 
	    $base = &get_utr_seq($coord,$strand,$organism,$chromosome);
	}

	$base_count++;

	if ($screen->{$transcript}->{$pos}) {$base = "N";}

	$transcript_seq->{$base_count}->{base}=$base;
	$transcript_seq->{$base_count}->{transcript}=$transcript;
	$transcript_seq->{$base_count}->{exon}="$exon,$region";
	if ($masked_base) {
	    if ($screen->{$transcript}->{$pos}) {$masked_base = "N";}
	    $transcript_seq->{$base_count}->{masked_base}=$masked_base;
	}
	
	$nb++;
	if ($trans_pos) {
	    my ($tp_position,$tp_region) = $trans_pos =~ /(\S+)\,(\S+)/;
	    if ($tp_position eq $target_position) {
		
		$transcript_seq->{$base_count}->{trans_pos}="$exon,$region,$pos,$base_count,$tp_region,$target_position";
		$target->{tp_regoin}=$tp_region;
		$target->{exon}=$exon;
		$target->{base_count}=$base_count;
		
	    }
	}
    }
    unless ($target->{exon}) {
        print qq(couldn't find the target position in the transcript\n);
        $target->{exon}=0;
    }
    unless ($target->{base_count}){$target->{base_count}=0;}
    unless ($target->{tp_regoin}){$target->{tp_regoin}=0;}
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
#    if ($err) {
#	    print qq($err\n);
#    }
#    if ($out) {
#    	return ($out);
#    	print qq($out\n);
#    }
    return ($obj);
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
		$annotation_info->{$transcript}->{$start}->{gene}=$gene;
		$annotation_info->{$transcript}->{$start}->{transcript}=$transcript;
		$annotation_info->{$transcript}->{$start}->{strand}=$strand;
		$annotation_info->{$transcript}->{$start}->{trv_type}=$trv_type;
		$annotation_info->{$transcript}->{$start}->{trans_pos}=$start;
		$annotation_info->{$transcript}->{$start}->{stop}=$stop;
		$annotation_info->{$transcript}->{$start}->{chromosome}=$chromosome;
		$annotation_info->{$transcript}->{$start}->{transcript_species}=$transcript_species;
		$annotation_info->{$transcript}->{$start}->{output_name} = "$gene.$transcript.$chromosome.$start";
	    }
	}
    } close (ANO);
    return($annotation_info);
}

sub get_screen_snp_list {

    my ($transcript,$transcript_info,$self) = @_;
    my $chr = $transcript_info->{$transcript}->{-1}->{chromosome};
    my $start = $transcript_info->{$transcript}->{-1}->{first_base};
    my $stop = $transcript_info->{$transcript}->{-1}->{last_base};

    my $screen_file = $self->screen_snp_list;
    my $screen;

    open(SCREEN,$screen_file) || die ("couldn't open the screen file\n\n");
    while (<SCREEN>) {
        chomp;
        my $line = $_;
        my ($chrom,$pos) = (split(/[\s]+/,$line))[0,1];
        if ($chr eq $chrom) {
            if ($pos >= $start && $pos <= $stop) {
                $screen->{$transcript}->{$pos}=1;
            }
        }
    } close (SCREEN);
    return($screen);
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
