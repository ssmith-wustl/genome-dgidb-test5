package Genome::Model::Tools::Somatic::VcfMakerTcga;

use strict;
use warnings;
use Genome;
use File::stat;
use Time::localtime;
use IO::File;
use File::Basename;
use Getopt::Long;
use FileHandle;
use POSIX qw(log10);
use POSIX qw(strftime);
use List::MoreUtils qw(firstidx);
use List::MoreUtils qw(uniq);

class Genome::Model::Tools::Somatic::VcfMakerTcga {
    is => 'Command',
    has => [
        output_file => {
            is => 'Text',
            is_output => 1,
            doc => "List of mutations in Vcf format",
        },

	tumor_bam_file => {
	    is => 'Text',
	    doc => "Tumor sample bam file (don't need complete path)" ,
	    is_optional => 0,
	    is_input => 1},

	normal_bam_file => {
	    is => 'Text',
	    doc => "Normal sample bam file (don't need complete path)" ,
	    is_optional => 0,
	    is_input => 1},

	file_source => {
	    is => 'Text',
	    doc => "source of the bam files",
	    is_optional => 1,
	    is_input => 1,
	    default =>"dbGap" },

	somatic_capture_dir => {
	    is => 'Text',
	    doc => "Build directory for the somatic capture pipeline",
	    is_optional => 0,
	    is_input => 1},

	dbsnp_file => {
	    is => 'Text',
	     doc => "dbsnp File " ,
	     is_optional => 1,
	     is_input => 1,
	    default => ""},

	tcga_id => {
	    is => 'Text',
	    doc => "TCGA id in format TCGA-00-0000" ,
	    is_optional => 0,
	    is_input => 1},

	center => {
	    is => 'Text',
	    doc => "Genome center name (WUSTL, Broad, Baylor)" ,
	    is_optional => 1,
	    default => "WUSTL",
	    is_input => 1},

	chrom => {
	    is => 'Text',
	    doc => "do only this chromosome" ,
	    is_optional => 1,
	    default => "",
	    is_input => 1},

	cp_score_to_qual => {
	    is => 'Boolean',
	    doc => "copy the somatic score to the qual field for Mutation WG comparisons" ,
	    is_optional => 1,
	    default => 0,
	    is_input => 1},

	genome_build => {
	    is => 'Text',
	    doc => "Reference genome build" ,
	    is_optional => 1,
	    default => "36",
	    is_input => 1},

	],    
};


sub help_brief {                            # keep this to just a few words <---
    "Generate Vcf File from TCGA exome data run through the somatic-capture pipeline"
}


sub help_synopsis {
    <<'HELP';
Generate a VCF File from TCGA exome data run through the somatic-capture pipeline
HELP
}

sub help_detail {                  # this is what the user will see with the longer version of help. <---
    <<'HELP';
Given the directory of the somatic-capture pipeline (as of April 2011), this parses the relevant files and creates a VCF containing all the SNVs. This includes those that fail filters (noted in the FILTER field).
HELP
}



################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
    my $self = shift;

    my $output_file = $self->output_file;
    my $tumor_bam = $self->tumor_bam_file;
    my $normal_bam = $self->normal_bam_file;
    my $file_source = $self->file_source;


#	my $sniper_file = $self->sniper_file;
#	my $sniper_fp_file = $self->sniper_fp_file;
#	my $sniper_series_file = $self->sniper_series_file;
    my $somatic_capture_dir = $self->somatic_capture_dir;
    my $tcga_id = $self->tcga_id;
    my $center = $self->center;
    my $genome_build = $self->genome_build;
    my $dbsnp_file = $self->dbsnp_file;
    my $chrom = $self->chrom;
    my $cp_score_to_qual = $self->cp_score_to_qual;


    my $analysis_profile = "somatic-sniper-and-varscan-capture";



###########################################################################
    sub convertIub{
	my ($base) = @_;
	my %iub_codes;
	$iub_codes{"A"}="A";
	$iub_codes{"C"}="C";
	$iub_codes{"G"}="G";
	$iub_codes{"T"}="T";
	$iub_codes{"U"}="T";
	$iub_codes{"M"}="A,C";
	$iub_codes{"R"}="A,G";
	$iub_codes{"W"}="A,T";
	$iub_codes{"S"}="C,G";
	$iub_codes{"Y"}="C,T";
	$iub_codes{"K"}="G,T";
	$iub_codes{"V"}="A,C,G";
	$iub_codes{"H"}="A,C,T";
	$iub_codes{"D"}="A,G,T";
	$iub_codes{"B"}="C,G,T";
	$iub_codes{"N"}="G,A,T,C";

	return $iub_codes{$base}
    };


#############################################################################
    sub print_header{
	my ($tumor_bam, $normal_bam, $center, $genome_build, $tcga_id, $file_source, $analysis_profile, $output_file) = @_;

	open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";

	my $reference;
	my $seqCenter;
	my $file_date = "04202011";#strftime("%m/%d/%Y %H:%M:%S\n", localtime);



	#fix this to support build 37 when necessary
	if ($genome_build ne "36"){
	    die("reference paths need to be added for other builds before using")
	}


	#center-specific lines:
	if ($center eq "WUSTL"){
	    $seqCenter = "genome.wustl.edu";
	    $reference = "ftp://ftp.ncbi.nlm.nih.gov/genomes/H_sapiens/ARCHIVE/BUILD.36.3/special_requests/assembly_variants/NCBI36_BCCAGSC_variant.fa.gz";
	}
	elsif($center eq "Broad"){
	    $seqCenter = "broad.mit.edu";
	    $reference="ftp://ftp.ncbi.nlm.nih.gov/genomes/H_sapiens/ARCHIVE/BUILD.36.3/special_requests/assembly_variants/NCBI36-HG18_Broad_variant.fa.gz";
	}
	elsif($center eq "Baylor"){
	    $seqCenter = "bcm.edu";
	    $reference="ftp://ftp.ncbi.nlm.nih.gov/genomes/H_sapiens/ARCHIVE/BUILD.36.3/special_requests/assembly_variants/NCBI36_BCCAGSC_variant.fa.gz";
	}

    
	#which type of sequencing was it?
	my $seqType = "";
	$seqType = "-whole" if($tumor_bam =~ /whole/i);
	$seqType = "-solid" if($tumor_bam =~ /solid/i);
	$seqType = "-illumina" if($tumor_bam =~ /illumina/i);

	print OUTFILE "##fileformat=VCFv4.1" . "\n";
	print OUTFILE "##fileDate=$file_date" . "\n";
	print OUTFILE "##reference=$reference" . "\n";
	print OUTFILE "##phasing=none" . "\n";
	print OUTFILE "##INDIVIDUAL=$tcga_id" . "\n";

	#first normal
	print OUTFILE "##SAMPLE=<ID=" . $tcga_id . $seqType . "-normal,file=" . $normal_bam . "SeqCenter=" . $seqCenter . ",Accession=phs000178.v4.p4,FileSource=" . $file_source . ",SequenceSource=" . $file_source . ",AnalysisProfile=" . $analysis_profile . "Type=normal_DNA>" . "\n";

	#then tumor
	print OUTFILE "##SAMPLE=<ID=" . $tcga_id . $seqType . "-tumor,file=" . $normal_bam . "SeqCenter=" . $seqCenter . ",Accession=phs000178.v4.p4,FileSource=" . $file_source . ",SequenceSource=" . $file_source . ",AnalysisProfile=" . $analysis_profile . "Type=tumor_DNA>" . "\n";

	# info lines
	print OUTFILE "##INFO=<ID=DB,Number=0,Type=Flag,Description=\"dbSNP membership, build 130\">" . "\n";
#	print OUTFILE "##INFO=<ID=VT,Number=1,Type=String,Description=\"Somatic variant type\">" . "\n";

	#all the filter info
	print OUTFILE "##FILTER=<ID=PASS,Description=\"Passed all filters\">" . "\n";
	print OUTFILE "##FILTER=<ID=snpfilter,Description=\"snp filter - Discard\">" . "\n"
	print OUTFILE "##FILTER=<ID=sniperhc,Description=\"Somatic Sniper Low Confidence - Discard\">" . "\n";
	print OUTFILE "##FILTER=<ID=fp,Description=\"False Positive Filter - Discard\">" . "\n";
	print OUTFILE "##FILTER=<ID=varscan,Description=\"Varscan Low Confidence - Discard\">" . "\n";
	print OUTFILE "##FILTER=<ID=loh,Description=\"Loss of Heterozygosity filter - Discard\">" . "\n";
	print OUTFILE "##FILTER=<ID=novel,Description=\"Novel event filter (inc. dbSNP) - Discard\">" . "\n";

	#format info
	print OUTFILE "##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">" . "\n";
	print OUTFILE "##FORMAT=<ID=GQ,Number=1,Type=Integer,Description=\"Genotype Quality\">" . "\n";
	print OUTFILE "##FORMAT=<ID=DP,Number=1,Type=Integer,Description=\"Total Read Depth\">" . "\n";
	print OUTFILE "##FORMAT=<ID=BQ,Number=1,Type=Integer,Description=\"Average Base Quality corresponding to alleles 0/1/2/3... after software and quality filtering\">" . "\n";
	print OUTFILE "##FORMAT=<ID=MQ,Number=1,Type=Integer,Description=\"Average Mapping Quality corresponding to alleles 0/1/2/3... after software and quality filtering\">" . "\n";
	print OUTFILE "##FORMAT=<ID=AD,Number=1,Type=Integer,Description=\"Allele Depth corresponding to alleles 0/1/2/3... after software and quality filtering\">" . "\n";
	print OUTFILE "##FORMAT=<ID=VAS,Number=1,Type=Integer,Description=\"Variant  Status relative to non-adjacent normal 0=Wildtype, 1=Germline, 2=Somatic, 3=LOH, 4=Post_Transcriptional_Modification, 5=Undefined\">" . "\n";
	print OUTFILE "##FORMAT=<ID=VAQ,Number=1,Type=Integer,Description=\"Quality score - sum of SomaticSniper and Varscan scores\">" . "\n";
	print OUTFILE "##FORMAT=<ID=VLS,Number=1,Type=Integer,Description=\"Validation  Status relative to non-adjacent reference normal 0=Wildtype, 1=Germline, 2=Somatic, 3=LOH, 4=Post_Transcriptional_Modification, 5=Undefined\">" . "\n";
	print OUTFILE "##FORMAT=<ID=VLQ,Number=1,Type=Integer,Description=\"Validation Score / Confidence\">" . "\n";
    
	#column header:
	print OUTFILE  "#" . join("\t", ("CHROM","POS","ID","REF","ALT","QUAL","FILTER","INFO","FORMAT","NORMAL","PRIMARY")) . "\n";
	OUTFILE->close();
    }
    



###################################################################

    #everything is hashed by chr:position, with subhashes corresponding to
    #tumor and normal samples, then the various VCF fields
    my %sniperSnvs;


    #First, read in the unfiltered files to get all of the calls
    #sniper first
    my $inFh = IO::File->new( "$somatic_capture_dir/sniper/snps_all_sequences" ) || die "can't open file\n";

    while( my $line = $inFh->getline ){

	chomp($line);
	my @col = split("\t",$line);

	#if we do this on a per-chrom process (for huge files)
	unless ($chrom eq ""){
	    next if($col[0] ne $chrom)
	}


	my $chr = $col[0];
	#replace X and Y for sorting
	$chr = "23" if $col[0] eq "X";
	$chr = "24" if $col[0] eq "Y";
	$chr = "25" if $col[0] eq "MT";
	my $id = $chr . ":" . $col[1];

	#skip MT and NT chrs
	#next if $col[0] =~ /^MT/;
	next if $col[0] =~ /^NT/;

	#replace X and Y for sorting
	$sniperSnvs{$id}{"chrom"} = $col[0];
	$sniperSnvs{$id}{"pos"} = $col[1];

	#get all the alleles together (necessary for the GT field)
	my @alleles = ($col[2]);

	my @tmp = split(",",convertIub($col[3]));
	#only add non-reference alleles to the alt field
	foreach my $alt (@tmp){
	    unless ($alt eq $col[2]){
		push(@alleles,$alt);
	    }
	}
	if ($col[2] =~ /[ACGTN]/){
	    $sniperSnvs{$id}{"ref"} = $col[2];
	} else {
	    $sniperSnvs{$id}{"ref"} = "N";
	}
	$sniperSnvs{$id}{"alt"} = join(",",@alleles[1..(@alleles-1)]);

	#add the ref and alt alleles' positions in the allele array to the GT field
	#ref
	my @toSort = ((firstidx{ $_ eq $col[2] } @alleles),(firstidx{ $_ eq $col[2] } @alleles));
	$sniperSnvs{$id}{"normal"}{"GT"} = join(",",sort(@toSort));


	#alt
	my @tumGT=split(",",convertIub($col[3]));
	if (@tumGT > 1){
	    my @toSort = ((firstidx{ $_ eq $tumGT[0] } @alleles),(firstidx{ $_ eq $tumGT[1] } @alleles));
	    $sniperSnvs{$id}{"tumor"}{"GT"} = join(",",sort(@toSort));

	} else {
	    my @toSort = ((firstidx{ $_ eq $col[3] } @alleles),(firstidx{ $_ eq $col[3] } @alleles));
	    $sniperSnvs{$id}{"tumor"}{"GT"} = join(",",sort(@toSort));
	}


	#genotype quality
	$sniperSnvs{$id}{"normal"}{"GQ"} = ".";
	$sniperSnvs{$id}{"tumor"}{"GQ"} = $col[6];

	#total read depth
	$sniperSnvs{$id}{"normal"}{"DP"} = $col[9];
	$sniperSnvs{$id}{"tumor"}{"DP"} = $col[8];

	#these fields all change based on whether the ref matches the var
#	if ($col[2] eq $col[3]){
	#avg base quality ref/var
	$sniperSnvs{$id}{"normal"}{"BQ"} =  ".";
	$sniperSnvs{$id}{"tumor"}{"BQ"} =  $col[8] . "/.";
	#avg mapping quality ref/var
	$sniperSnvs{$id}{"normal"}{"MQ"} =  ".";
	$sniperSnvs{$id}{"tumor"}{"MQ"} =  $col[7] . "/.";
	#allele depth
	$sniperSnvs{$id}{"normal"}{"AD"} =  ".";
	$sniperSnvs{$id}{"tumor"}{"AD"} =  ".";
#	} else {
#	    #avg base quality ref/var
#	    $sniperSnvs{$id}{"normal"}{"BQ"} =  $col[20] . "/" . $col[23];
#	    $sniperSnvs{$id}{"normal"}{"BQ"} =  $col[14] . "/" . $col[17];
#	    #avg mapping quality ref/var
#	    $sniperSnvs{$id}{"normal"}{"MQ"} =  $col[21] . "/" . $col[24];
#	    $sniperSnvs{$id}{"normal"}{"MQ"} =  $col[15] . "/" . $col[18];
#	    #allele depth
#	    $sniperSnvs{$id}{"normal"}{"AD"} =  $col[22] . "/" . $col[25];
#	    $sniperSnvs{$id}{"normal"}{"AD"} =  $col[16] . "/" . $col[19];
#	}

	#vas
	$sniperSnvs{$id}{"normal"}{"VAS"} = 0;
	$sniperSnvs{$id}{"tumor"}{"VAS"} = 2;

	#vaq
	$sniperSnvs{$id}{"normal"}{"VAQ"} = ".";
	$sniperSnvs{$id}{"tumor"}{"VAQ"} = $col[5];

	#vls
	$sniperSnvs{$id}{"normal"}{"VLS"} = ".";
	$sniperSnvs{$id}{"tumor"}{"VLS"} = ".";
	#vlq
	$sniperSnvs{$id}{"normal"}{"VLQ"} = ".";
	$sniperSnvs{$id}{"tumor"}{"VLQ"} = ".";
    }
    $inFh->close();


#-----------------------------------------
#next read in the complete Varscan file

    my %varScanSnvs;
    $inFh = IO::File->new( "$somatic_capture_dir/varScan.output.snp.formatted.Somatic" ) || die "can't open file\n";

    $inFh->getline; #skip header
    while(my $line = $inFh->getline )
    {
	chomp($line);
	my @col = split("\t",$line);

	#if we do this on a per-chrom process (for huge files)
	unless ($chrom eq ""){
	    next if($col[0] ne $chrom)
	}

	my $chr = $col[0];
	#replace X and Y for sorting
	$chr = "23" if $col[0] eq "X";
	$chr = "24" if $col[0] eq "Y";
	$chr = "25" if $col[0] eq "MT";
	my $id = $chr . ":" . $col[1];

	my $score = sprintf "%.2f", -10*log10($col[15]);

	#skip MT and NT chrs
	#next if $col[0] =~ /^MT/;
	next if $col[0] =~ /^NT/;

	$varScanSnvs{$id}{"chrom"} = $col[0];
	$varScanSnvs{$id}{"pos"} = $col[1];


	#get all the alleles together (necessary for the GT field)
	my @alleles = ($col[3]);

	my @tmp = split(",",convertIub($col[4]));
	#only add non-reference alleles to the alt field
	foreach my $alt (@tmp){
	    unless ($alt eq $col[3]){
		push(@alleles,$alt);
	    }
	}

	$varScanSnvs{$id}{"ref"} = $col[3];
	$varScanSnvs{$id}{"alt"} = join("/",@alleles[1..(@alleles-1)]);


	# #get all the alleles together (necessary for the GT field)
	# my @alleles = split(",",convertIub($col[2]));
	# my @tmp = split(",",convertIub($col[11]));
	# @alleles = (@alleles,@tmp);
	# @tmp = split(",",convertIub($col[7]));
	# @alleles = (@alleles,@tmp);

	# $varScanSnvs{$id}{"ref"} = convertIub($col[2]);
	# $varScanSnvs{$id}{"alt"} = join("/",@alleles[1..(@alleles-1)]);

	#add the ref and alt alleles' positions in the allele array to the GT field
	my @normGT=split(",",convertIub($col[8]));
	if (@normGT > 1){
	    my @toSort = ((firstidx{ $_ eq $normGT[0] } @alleles),(firstidx{ $_ eq $normGT[1] } @alleles));
	    $varScanSnvs{$id}{"normal"}{"GT"} = join("/",sort(@toSort));
	} else {
	    $varScanSnvs{$id}{"normal"}{"GT"} = (firstidx{ $_ eq $col[8] } @alleles). "/" . (firstidx{ $_ eq $col[8] } @alleles);
	}

	my @tumGT=split(",",convertIub($col[12]));
	if (@tumGT > 1){
	    my @toSort = ((firstidx{ $_ eq $tumGT[0] } @alleles),(firstidx{ $_ eq $tumGT[1] } @alleles));
	    $varScanSnvs{$id}{"tumor"}{"GT"} = join("/",sort(@toSort));
	} else {
	    $varScanSnvs{$id}{"tumor"}{"GT"} = (firstidx{ $_ eq $col[12] } @alleles). "/" . (firstidx{ $_ eq $col[12] } @alleles);
	}


	#genotype quality
	$varScanSnvs{$id}{"normal"}{"GQ"} = ".";
	$varScanSnvs{$id}{"tumor"}{"GQ"} = ".";

	#total read depth
	$varScanSnvs{$id}{"normal"}{"DP"} = $col[5]+$col[6];
	$varScanSnvs{$id}{"tumor"}{"DP"} = $col[9]+$col[10];

	#avg base quality ref/var
	$varScanSnvs{$id}{"normal"}{"BQ"} =  ".";
	$varScanSnvs{$id}{"tumor"}{"BQ"} =  ".";

	#avg mapping quality ref/var
	$varScanSnvs{$id}{"normal"}{"MQ"} =  ".";
	$varScanSnvs{$id}{"tumor"}{"MQ"} =  ".";

	#allele depth  
	$varScanSnvs{$id}{"normal"}{"AD"} =  $col[5] . "/" . $col[6];
	$varScanSnvs{$id}{"tumor"}{"AD"} =  $col[9] . "/" . $col[10];

	#vas
	if (($col[2] ne $col[7]) && ($col[3] eq $col[11])){
	    $varScanSnvs{$id}{"normal"}{"VAS"} = 1;
	    $varScanSnvs{$id}{"tumor"}{"VAS"} = 1;
	} else {
	    $varScanSnvs{$id}{"normal"}{"VAS"} = 0;
	}
	$varScanSnvs{$id}{"tumor"}{"VAS"} = 2;

	#vaq
	$varScanSnvs{$id}{"normal"}{"VAQ"} = ".";
	$varScanSnvs{$id}{"tumor"}{"VAQ"} = $score;

	#vls
	$varScanSnvs{$id}{"normal"}{"VLS"} = ".";
	$varScanSnvs{$id}{"tumor"}{"VLS"} = ".";
	#vlq
	$varScanSnvs{$id}{"normal"}{"VLQ"} = ".";
	$varScanSnvs{$id}{"tumor"}{"VLQ"} = ".";
    }

    $inFh->close();


#-------------------------------------------
#Next, go through all the filtered files, match up the snps,
#and add a label to the filter field if it's removed

    sub addFilterInfo{
	my ($filename,$filtername,$snvHashRef) = @_;

	#read in all the sites that passed the filter
	my %passingSNVs;

	my $inFh2 = IO::File->new( "$somatic_capture_dir/$filename" ) || die "can't open file\n";
	while( my $line = $inFh2->getline )
	{
	    chomp($line);
	    my @col = split("\t",$line);
	    my $id = $col[0] . ":" . $col[1];

	    $passingSNVs{$id} = 1;
	}
	$inFh->close();

	#check each stored SNV
	foreach my $key (keys( %{$snvHashRef} )){
	    #if it did not pass this filter
	    unless(exists($passingSNVs{$key})){
		#and hasn't already been filtered out
		unless(exists(%{$snvHashRef}->{$key}{"filter"})){
		    #add the filter name
		    %{$snvHashRef}->{$key}{"filter"} = $filtername;
		}
	    }
	}
    }


    addFilterInfo("varScan.output.snp.formatted.Somatic.hc", "varscan", \%varScanSnvs);

    addFilterInfo("somaticSniper.output.snp.filter","snpfilter",\%sniperSnvs);
    addFilterInfo("somaticSniper.output.snp.filter.hc","sniperhc",\%sniperSnvs);
    addFilterInfo("somaticSniper.output.snp.filter.hc.somatic","loh",\%sniperSnvs);


#-------------------------------------------
# Now we're ready to combine the calls from sniper and varscan
# and just merge them into the varscan hash (since we have better GT calls)

    foreach my $key (keys(%sniperSnvs)){
	#if already called by sniper
	if (exists($varScanSnvs{$key})){

	    #sum scores
	    $varScanSnvs{$key}{"tumor"}{"VAQ"} = $varScanSnvs{$key}{"tumor"}{"VAQ"} + $sniperSnvs{$key}{"tumor"}{"VAQ"};
	    #combine filters
	    if(exists($varScanSnvs{$key}{"filter"}) && exists($sniperSnvs{$key}{"filter"})){
		$varScanSnvs{$key}{"filter"} = dedupFilterNames($varScanSnvs{$key}{"filter"},$sniperSnvs{$key}{"filter"});
	    }
	} else {
	    #just add it
	    $varScanSnvs{$key} = $sniperSnvs{$key}
	}


    }

    sub dedupFilterNames{
	my ($names1,$names2) = @_;
	my @n1 = split(",",$names1);
	my @n2 = split(",",$names2);
	return(join(";",uniq(sort(@n1,@n2))))
    }


#finally, remove those in the novel filter
    addFilterInfo("merged.somatic.snp.filter", "fp", \%varScanSnvs);
    addFilterInfo("merged.somatic.snp.filter.novel", "novel", \%varScanSnvs);


#---------------------------------------------
    ## add DBsnp labels
    if ($dbsnp_file ne ""){

	print STDERR "adding dbSNP info - this will take a few minutes\n";
	my $inFh = IO::File->new( $dbsnp_file ) || die "can't open file\n";
	while( my $line = $inFh->getline )
	{
	    unless($line =~ /^#/){
		chomp($line);
		my @fields = split("\t",$line);

		$fields[1] =~ s/chr//;

		#replace X and Y for sorting
		my $chr = $fields[1];
		$chr = "23" if $chr eq "X";
		$chr = "24" if $chr eq "Y";

		#ucsc is zero-based, so we adjust
		my $key = $chr . ":" . ($fields[2]+1);
		#if the line matches this dbsnp position
		if(exists($varScanSnvs{$key})){
		    #and the alleles match
		    if (($varScanSnvs{$key}{"alt"} . "/" . $varScanSnvs{$key}{"ref"} eq $fields[9])){
			#note the match in the info field
			if(exists($varScanSnvs{$key}{"info"})){
			    $varScanSnvs{$key}{"info"} = $varScanSnvs{$key}{"info"} . ";";
			} else {
			    $varScanSnvs{$key}{"info"} = "";
			}
			$varScanSnvs{$key}{"info"} = $varScanSnvs{$key}{"info"} . "DB";

			#add to id field
			if(exists($varScanSnvs{$key}{"id"})){
			    $varScanSnvs{$key}{"id"} = $varScanSnvs{$key}{"id"} . ";";
			} else {
			    $varScanSnvs{$key}{"id"} = "";
			}
			$varScanSnvs{$key}{"id"} = $varScanSnvs{$key}{"id"} . $fields[4];


#			#if the filter shows a pass, remove it and add dbsnp
#			if($varScanSnvs{$key}->{FILTER} eq "PASS"){
#			    $varScanSnvs{$key}->{FILTER} = "dbSNP";
#			} else { #add dbsnp to the list
#			    $varScanSnvs{$key}->{FILTER} = $varScanSnvs{$key}->{FILTER} . ",dbSNP";
#			}

		    }
		}
	    }
	}
    }


#---------------------------------------------
    sub print_body{
	my ($output_file,$snvHash) = @_;

	open(OUTFILE, ">>$output_file") or die "Can't open output file: $!\n";
	my %snvhash = %{$snvHash};
	
	#sort by chr, start for clean output
	sub keySort{
	    my($x,$y) = @_;
	    my @x1 = split(":",$x);
	    my @y1 = split(":",$y);
	    return($x1[0] <=> $y1[0] || $x1[1] <=> $y1[1])
	}
	my @sortedKeys = sort { keySort($a,$b) } keys %snvhash;

	foreach my $key (@sortedKeys){
	    my @outline;
	    push(@outline, $snvhash{$key}{"chrom"});
	    push(@outline, $snvhash{$key}{"pos"});


	    #ID
	    if (exists($snvhash{$key}{"id"})){
		push(@outline, $snvhash{$key}{"id"});
	    } else {
		push(@outline, ".");
	    }

	    #ref/alt
	    push(@outline, $snvhash{$key}{"ref"});
	    push(@outline, $snvhash{$key}{"alt"});

	    #QUAL
	    if (exists($snvhash{$key}{"qual"})){
		push(@outline, $snvhash{$key}{"qual"});
	    } else {
		if ($cp_score_to_qual){
		    push(@outline, $snvhash{$key}{"tumor"}{"VAQ"});
		} else {		    
		    push(@outline, ".");
		}
	    }

	    #FILTER
	    if (exists($snvhash{$key}{"filter"})){
		push(@outline, $snvhash{$key}{"filter"});
	    } else {
		push(@outline, "PASS");
	    }

	    #INFO
	    push(@outline, ".");

	    #FORMAT
	    push(@outline, "GT:GQ:DP:BQ:MQ:AD:VAS:VAQ:VLS:VLQ");

	    my @normalFormat;
	    my @tumorFormat;
	    my @fields = ("GT","GQ","DP","BQ","MQ","AD","VAS","VAQ","VLS","VLQ");
	    #collect format fields
	    foreach my $field (@fields){
		push(@normalFormat, $snvhash{$key}{"normal"}{$field});
		push(@tumorFormat, $snvhash{$key}{"tumor"}{$field});
	    }
	    push(@outline, join(":",@normalFormat));
	    push(@outline, join(":",@tumorFormat));

	    print OUTFILE join("\t",@outline) . "\n";
	}
    }

#----------------------------------

    print_header($tumor_bam, $normal_bam, $center, $genome_build, $tcga_id, $file_source, $analysis_profile,$output_file);
    print_body($output_file, \%varScanSnvs);
    return 1;
}
