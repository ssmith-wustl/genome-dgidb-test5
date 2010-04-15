package Genome::Model::Tools::Consed::TagManualPolySite;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Consed::TagManualPolySite {
    is => 'Command',                       
    has => [ 
	ace_file => {
            type  =>  'String',
            doc  => "manditory; ace file name",
	},
	refseq_fasta => {
            type  =>  'String',
            doc  => "optional; default attempts to find this file based on the refseq_id; refseq_id.c1.refseq.fasta file",
        },
	snp_gff => {
            type  =>  'String',
            doc   => "provide a name for the snp_gff file if it doesn't exsist it will be written",
  	    is_optional  => 1,
        },
	polyscan_snp => {
            type  =>  'String',
            doc   => 'the polyscan-snp file',
  	    is_optional  => 1,
        },
	force_genotype_coords => {
            type  =>  'String',
            doc   => 'optional provide a file of coordinates to force genotype; File format must be first column chromosome second column chromosomal coordinate columns should be seperated by space or tab',
  	    is_optional  => 1,
        },
	
	], 
};

sub help_brief {                            

"A tool to used to write manualPolySite tags in a consed ace file"

}

sub help_synopsis { 

    return <<EOS

	gmt consed tag-manual-poly-site -h

EOS
}


sub help_detail {
    return 'This tool was designed to insert manualPolySite tags in a consed ace file';
}



sub execute {

    my $self = shift;

    my $polyscan_snp = $self->polyscan_snp;
    my $force_genotype_coords = $self->force_genotype_coords;
    my $ace_file = $self->ace_file;
    my $refseq_fasta = $self->refseq_fasta;

###This section uses the ace object to detirmine the contig of interest
    my ($ace_reference_info) = Genome::Model::Tools::Consed::AceReference->execute(ace_file => $ace_file, name_and_number => 1, no_stdout => 1);
    unless ($ace_reference_info) {$self->error_message("unable to get the ace object");return;}
    my $ace_reference = $ace_reference_info->result;
    unless ($ace_reference) { $self->error_message("unable to find the reseqid and contig_number");return;}
    my $Contig_number = $ace_reference->{Contig_number};
    my $reseqid = $ace_reference->{reseqid};
    unless ($Contig_number && $reseqid) {$self->error_message("unable to find the reseqid and contig_number");return;}
    
###This section gets coordinate conversion info from the refseq fasta
    my ($ref_head_info) = Genome::Model::Tools::RefSeq::Fasta->execute(refseq_fasta => $refseq_fasta, no_stdout => 1);
    unless ($ref_head_info) {$self->error_message("unable to get the reference sequence fasta object");return;}
    my $ref_head = $ref_head_info->result;
    unless ($ref_head){$self->error_message("unable to parse reference sequence fasta file header");return;}
    my $length = $ref_head->{length};
    my $chromosome = $ref_head->{chromosome};
    my $genomic_coord = $ref_head->{genomic_coord};
    my $orientation = $ref_head->{orientation};

###########This step grabs all the refseq positions from the polyscan out file
    my $polyscan_positions;
    if ($polyscan_snp) {
	unless (-f $polyscan_snp) {$self->error_message("Could not find the polyscan file provided.");return;}
	$polyscan_positions = &get_polyscan_positions($self,$polyscan_snp);
    }

###########This step grabs all the refseq positions from the force_genotype_coords file
    my $force_positions;
    if ($force_genotype_coords) {
	unless (-f $force_genotype_coords) {$self->error_message("Could not find the force_genotype_coords file provided.");return;}
	$force_positions = &get_force_positions($self,$force_genotype_coords,$ref_head);
    }

###########This step grabs all the refseq positions from the snp.gff file (optional)
    my $dbsnp_positions;
    if ($self->snp_gff) {
	my $snp_gff = $self->snp_gff;
	if (-f $snp_gff) {

	    $dbsnp_positions = &get_dbsnp_positions($self,$ref_head,$snp_gff);

	} else {

	    my $start = $ref_head->{start};
	    my $stop = $ref_head->{stop};
	    
	    my $variant_file_line = $chromosome . "\t" . $start . "\t" . $stop . "\t" . "-" . "\t" . "-";
	    my $variant_file = "$snp_gff.gffvariant_file";
	    open(V,">$variant_file") && print V qq($variant_file_line\n) || $self->error_message("Could not write to $variant_file.");
	    close V;

	    my $output = "$snp_gff.genomic";
	    my $gff = Genome::Model::Tools::Annotate::LookupVariants->execute(report_mode => "gff", variant_file => "$variant_file", output_file => "$output");
	    if ($gff) {
		my $snp_gff = &convert_gff($self,$snp_gff,$ref_head);
		$dbsnp_positions = &get_dbsnp_positions($self,$ref_head,$snp_gff);
	    }
	    `rm $variant_file`;
	    `rm $output`;
	}
    }

    my $snp;
    foreach my $pos (keys %{$polyscan_positions}) {
	my $comment = $polyscan_positions->{$pos};
	$snp->{$pos} = $comment;
    }
    foreach my $pos (keys %{$dbsnp_positions}) {
	my $comment = $dbsnp_positions->{$pos};
	if ($snp->{$pos}) {
	    $comment = "$snp->{$pos}\:\:$comment";
	}
	$snp->{$pos} = $comment;
    }
    foreach my $pos (keys %{$force_positions}) {
	my $comment = $force_positions->{$pos};
	if ($snp->{$pos}) {
	    $comment = "$snp->{$pos}\:\:$comment";
	}
	$snp->{$pos} = $comment;
    }
    
    
######################################################################################
###This section count the pads in the consensus, converts the snp.gff and polyscan_snp
###refseq positions to padded position and writes tags to the ace file.

    if ($snp) {
	my $base_pad_count = &Count_pads($self,$ace_file,$Contig_number);#count the pads in the consensus
	unless ($base_pad_count) {
	    $self->error_message("couldn't get a base_pad_count from the ace file.\n");
	    return;
	}
	my $tags = &write_tags($self,$ace_file,$snp,$base_pad_count,$Contig_number,$length);
	if ($tags) {
	    return 1;
	} else {
	    $self->error_message("failed to tag.\n"); 
	    return;
	}
    } else {
	$self->error_message("sites were found for tagging.\n"); 
	return 1;
    }
}

sub write_tags {

    my ($self,$ace_file,$snp,$base_pad_count,$Contig_number,$length) = @_;

    open (MPSTAG, ">mpstag") || $self->error_message("Could not open mpstag for writting") && return;
    print MPSTAG "\n";
    
    foreach my $pos (sort {$a<=>$b} keys %{$snp}){
	    
	if (($pos > 0) && ($pos <= $length)) {
	    my $con_start = $pos + $base_pad_count->{$pos};
	    my $comment = $snp->{$pos};
	    chomp $comment;
	    my $tag_time = (`date +%y%m%d:%H%M%S`); #060717:163011
	    chomp $tag_time;
		
		
my $manualpolysite_tag = <<ETAG;
CT{
$Contig_number manualPolySite consed $con_start $con_start $tag_time
COMMENT{
$comment
C}
}
ETAG

    print MPSTAG ("$manualpolysite_tag\n");
		
		
	}
    }
    close MPSTAG;

    system ("cat mpstag >> $ace_file");
    system ("rm mpstag"); #pmtag");
    return 1;
}


sub Count_pads{

    my ($self,$ace_file,$Contig_number) = @_;

    my $base_pad_count;

    my $p;
    my $q;
    my @con_seq;

    open (ACE_file, "$ace_file") || die ("Could not open the ace file\n");
    my @seq_line = ();
    my @file = <ACE_file>;
    close (ACE_file);
    $p = 0;
    while (@file >= $p){
	$q = 1;
	if ($file[$p]) {
	    if ($file[$p] =~ /CO $Contig_number/){
		until ($file[$p + $q] =~ /BQ/){
		    chomp $file[$p + $q];
		    #print ("$file[$p + $q]");
		    @seq_line = split(//, $file[$p + $q]);
		    chomp @seq_line;
		    push @con_seq, @seq_line;
		    
		    $q++;
		}
	    }
	}
	$p++;
    }

    my $pad_count = 0;
    my $base_number = 0;
    foreach my $base (@con_seq){
	#$base_number++;
	if ($base =~ /\*/) { 
	    $pad_count++;
	} else {
	    $base_number++;
	    $base_pad_count->{$base_number} = $pad_count;
	}
    }


    return $base_pad_count;

}

sub gen_coord {

    my ($self,$pos,$ref_head) = @_;

    my $genomic_coord = $ref_head->{genomic_coord};
    my $orientation = $ref_head->{orientation};

    my $chromosomal_coordinate;
    
    if ($orientation eq "plus") {
	$chromosomal_coordinate = $pos + $genomic_coord;
	
    } elsif ($orientation eq "minus") {
	$chromosomal_coordinate = $genomic_coord - $pos;
    }
    return $chromosomal_coordinate;
}

sub ref_coord {
    
    my ($self,$pos,$ref_head) = @_;

    my $genomic_coord = $ref_head->{genomic_coord};
    my $orientation = $ref_head->{orientation};
    
    my $ref_pos;
    if ($orientation eq "plus") {
	$ref_pos = $pos - $genomic_coord;
    } elsif ($orientation eq "minus") {
	$ref_pos = $genomic_coord - $pos;
    }
    return $ref_pos;
}

sub get_polyscan_positions {
    
    my $polyscan_positions;

    my ($self,$polyscanfile) = @_;
    
    use MG::IO::Polyscan;
    use MG::IO::Polyscan::Contig;
    
    my $polyscan=new MG::IO::Polyscan();
    $polyscan->readIn($polyscanfile);  #read in original polyphred.out
    
    my $id_contig = '0';
    my @contigs = MG::IO::Polyscan::getContig($polyscan,$id_contig);
    
    for my $contig (@contigs) {
	my $snps = MG::IO::Polyscan::Contig::getSNP_READSITES($contig);
	foreach my $pos (keys %{$snps}) {
	    $polyscan_positions->{$pos} = "polyscan_snp";
	    #print qq(polyscan_snp $pos\n);
	    
	}
	my $indels = MG::IO::Polyscan::Contig::getINDEL_READSITES($contig);
	foreach my $pos (keys %{$indels}) {
	    $polyscan_positions->{$pos} = "polyscan_indel";
	    #print qq(polyscan_indel $pos\n);
	}
    }

    return unless $polyscan_positions;
    return $polyscan_positions;

}

sub get_force_positions {

    my $force_positions;
    my ($self,$force_genotype_coords,$ref_head) = @_;
    
    my $chromosome = $ref_head->{chromosome};
    my $genomic_coord = $ref_head->{genomic_coord};
    my $orientation = $ref_head->{orientation};
    my $length = $ref_head->{length};

    open(FCG,$force_genotype_coords) || $self->error_message("Could not find the polyscan file provided.") && return;
    while (<FCG>) {
	chomp;
	my $line = $_;
	my ($chr,$pos) = (split(/[\s]+/,$line))[0,1];
	if ($chr eq $chromosome) {
	    my $ref_pos = &ref_coord($self,$pos,$ref_head);
	    if ($ref_pos > 0 && $ref_pos <= $length) {
		$force_positions->{$ref_pos} = "FCG";
	    }
	}
    }
    close(FCG);
    return unless $force_positions;
    return $force_positions;   
}

sub convert_gff {

    my ($self,$snp_gff,$ref_head) = @_;

    open(GFF, "$snp_gff.genomic") || $self->error_message("Could not open the snp_gff for conversion") && return;
    open(SNP_GFF,">$snp_gff") || $self->error_message("Could not open the snp_gff for for writting") && return;

    while (<GFF>) {
	chomp;
	my $line = $_;
	my @gff = split(/\t/,$line);
	my $chr_name = $gff[0];
	my $snp_start = $gff[3];
	my $snp_stop = $gff[4];
	my $ref_start = &ref_coord($self,$snp_start,$ref_head);
	my $ref_stop = &ref_coord($self,$snp_stop,$ref_head);
	my $name = $ref_head->{name};
	my $n = 0;
	for my $bit (@gff) {
	    $n++;

	    if ($bit eq $chr_name) {
		print SNP_GFF qq($name);
	    } elsif ($bit eq $snp_start) {
		print SNP_GFF qq($ref_start);
	    } elsif ($bit eq $snp_stop) {
		print SNP_GFF qq($ref_stop);
	    } else {
		print SNP_GFF qq($bit);
	    }
	    if ($n == @gff) {
		print SNP_GFF qq(\n);
	    } else {
		print SNP_GFF qq(\t);
	    }
	}
    }
    close (GFF);
    close (SNP_GFF);

    return unless (-f $snp_gff);
    return ($snp_gff);
    
}

sub get_dbsnp_positions {
    my $dbsnp_positions;

    my ($self,$ref_head,$snp_gff) = @_;

    my $length = $ref_head->{length};


    open (GFF, "$snp_gff")|| die ("Could not open the snp.gff file");
    while (<GFF>){
	chomp;
	my $line=$_;
	my @gff = split(/\t/,$line);
	my $snp_start = $gff[3];
	
	if (($snp_start > 0) && ($snp_start <= $length)) {
	    
	    my ($dbSNP_origin) = (split(/[\s]+/,$gff[8]))[0];
	    unless ($dbSNP_origin) {$dbSNP_origin = "dbsnp";}
	    $dbsnp_positions->{$snp_start}=$dbSNP_origin;
	}
    }
    close (GFF);
    return $dbsnp_positions;
}

1;
