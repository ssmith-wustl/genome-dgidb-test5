#!/gsc/bin/perl


use strict;
use warnings;
use lib '/gscuser/xshi/svn/mp';
use MG::Analysis::VariantAnnotation;
my $read_hash_unique_dna=MG::Analysis::VariantAnnotation->add_unique_reads_count($ARGV[1]);
my $read_hash_cDNA=MG::Analysis::VariantAnnotation->add_reads_count($ARGV[2]);
my $read_hash_unique_cDNA=MG::Analysis::VariantAnnotation->add_unique_reads_count($ARGV[3]);
my $read_hash_relapse_cDNA=MG::Analysis::VariantAnnotation->add_reads_count($ARGV[4]);


open (IN, "<$ARGV[0]") or die "Can't open $ARGV[0]. $!";
  
open (OUT, ">$ARGV[0].read") or die "Can't open $ARGV[0].read. $!";
  
print OUT qq{"dbSNP(0:no; 1:yes)",Gene_name,Chromosome,"Start_position (B36)","End_position (B36)",Variant_allele,"# of genomic reads supporting variant allele","# of cDNA reads supporting variant allele","# of unique genomic reads supporting variant allele(starting point)","# of unique genomic reads supporting variant allele(context)","# of unique cDNA reads supporting variant allele(starting point)","# of unique cDNA reads supporting variant allele(context)","# of relapse cDNA reads supporting variant allele",Reference_allele,"# of genomic reads supporting reference allele","# of cDNA reads supporting reference allele","# of unique genomic reads supporting reference allele(starting point)","# of unique genomic reads supporting reference allele(context)","# of unique cDNA reads supporting reference allele(starting point)","# of unique cDNA reads supporting reference allele(context)","# of relapse cDNA reads supporting reference allele",Gene_expression,Detection,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction,"submit(0:no; 1:yes)"\n};

 while(<IN>){
 chomp(); 
 my $line=$_;
 next if($line=~/dbSNP/);  
 my ($dbsnp,$gene,$chromosome,$start,$end,$al1,$al1_read_hg,$al1_read_cDNA,$al2,$al2_read_hg,$al2_read_cDNA,$gene_exp,$gene_det,$transcript,$strand,$trv_type,$c_position,$pro_str,$pph_prediction,$submit,$rgg_id) =  split(/,/)  ; 
  my ($al1_read_unique_dna_start,$al2_read_unique_dna_start,$al1_read_unique_dna_context,$al2_read_unique_dna_context);
  my ($al1_read_relapse_cDNA,$al2_read_relapse_cDNA,$al1_read_unique_cDNA_start,$al2_read_unique_cDNA_start,$al1_read_unique_cDNA_context,$al2_read_unique_cDNA_context);
  
  my $read_unique_dna=$read_hash_unique_dna->{$chromosome}->{$start};
  my $read_cDNA=$read_hash_cDNA->{$chromosome}->{$start};
  my $read_unique_cDNA=$read_hash_unique_cDNA->{$chromosome}->{$start}; 
  my $read_relapse_cDNA=$read_hash_relapse_cDNA->{$chromosome}->{$start}; 
 
  if(defined $read_unique_dna ) {
	$al1_read_unique_dna_start=$read_unique_dna->{$al1}->{start};
	$al2_read_unique_dna_start=$read_unique_dna->{$al2}->{start};
	$al1_read_unique_dna_context=$read_unique_dna->{$al1}->{context};
	$al2_read_unique_dna_context=$read_unique_dna->{$al2}->{context};
  }
  else{
	$al1_read_unique_dna_start=0;
	$al2_read_unique_dna_start=0;
	$al1_read_unique_dna_context=0;
	$al2_read_unique_dna_context=0;
  }


  if(defined $read_cDNA ) {
	$al1_read_cDNA=$read_cDNA->{$al1}; 
  	$al2_read_cDNA=$read_cDNA->{$al2};
  }
  else {
	$al1_read_cDNA=0;
        $al2_read_cDNA=0;
  }

  if(defined $read_unique_cDNA ) {
        $al1_read_unique_cDNA_start=$read_unique_cDNA->{$al1}->{start};
        $al2_read_unique_cDNA_start=$read_unique_cDNA->{$al2}->{start};
	$al1_read_unique_cDNA_context=$read_unique_cDNA->{$al1}->{context};
        $al2_read_unique_cDNA_context=$read_unique_cDNA->{$al2}->{context};
  }
  else {
        $al1_read_unique_cDNA_start=0;
        $al2_read_unique_cDNA_start=0;
	$al1_read_unique_cDNA_context=0;
        $al2_read_unique_cDNA_context=0;
  }
 
  if(defined $read_relapse_cDNA ) {
        $al1_read_relapse_cDNA=$read_relapse_cDNA->{$al1};
        $al2_read_relapse_cDNA=$read_relapse_cDNA->{$al2};
  }
  else {
        $al1_read_relapse_cDNA=0;
        $al2_read_relapse_cDNA=0;
  }
  print OUT "$dbsnp,$gene,$chromosome,$start,$end,$al2,$al2_read_hg,$al2_read_cDNA,$al2_read_unique_dna_start,$al2_read_unique_dna_context,$al2_read_unique_cDNA_start,$al2_read_unique_cDNA_context,$al2_read_relapse_cDNA,$al1,$al1_read_hg,$al1_read_cDNA,$al1_read_unique_dna_start,$al1_read_unique_dna_context,$al1_read_unique_cDNA_start,$al1_read_unique_cDNA_context,$al1_read_relapse_cDNA,$gene_exp,$gene_det,$transcript,$strand,$trv_type,$c_position,$pro_str,$pph_prediction,$submit,$rgg_id\n";
}
print "final finished!\n";
 
close(IN);
close(OUT);

 


