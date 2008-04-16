#!/gsc/bin/perl


use strict;
use warnings;

use Getopt::Long;
use Carp;
use MPSampleData::DBI;
use MPSampleData::ExternalGeneId;
use MG::Analysis::VariantAnnotation;

my %options = (  
                'dev'         => undef,
 	     );
 
GetOptions(  
           'devel=s'       => \$options{'dev'},
	);
 
unless(defined($options{'dev'}))  {
    croak "usage $0 --dev <database sample_data/sd_test..>";
}
MG::Analysis::VariantAnnotation->change_db($options{dev});
 
my($Srv) = 'mysql2';
my($Uid) = "sample_data";
my($Pwd) = q{Zl0*rCh};
my($database) = "sd_test";
my  $gene_hash;
my ($X);
#$X cannot have 'my($X)' or else it will close every time.
($X = DBI->connect("DBI:mysql:$database:$Srv", $Uid, $Pwd))  or (die "fail to connect to datase \n");

my $sql = qq{
        select expression_intensity, detection from gene_expression ge 
        join gene_gene_expression gge on gge.expression_id=ge.expression_id
        join gene g on g.gene_id=gge.gene_id 
        join external_gene_id egi on egi.gene_id=g.gene_id 
        where (g.hugo_gene_name=?  or egi.id_value=?)  
        order by expression_intensity desc limit 1;
};
my ($sth) = $X->prepare($sql);
my $submitted;

open (SUB, "</gscuser/xshi/work/AML_SNP/Gene_to_check/AMP_SNP_set3.submit.091507.results.8oct2007.csv") or die "Can't open  $!";
while(<SUB>){
 next if(/dbSNP/);
 my ($dbsnp,$chrom,$start,$end,$a1,$g1,$g2,$a2)=split(/,/);
 $submitted->{"$chrom,$start,$end"}=1;
}
close(SUB);


open (IN, "<$ARGV[0]") or die "Can't open $ARGV[0]. $!";
  
 open (OUT, ">$ARGV[1]") or die "Can't open $ARGV[1]. $!";
  
 print OUT qq{"dbSNP(0:no; 1:yes)",Gene_name,Chromosome,"Start_position (B36)","End_position (B36)",Variant_allele,"# of genomic reads supporting variant allele","# of cDNA reads supporting variant allele",Reference_allele,"# of genomic reads supporting reference allele","# of cDNA reads supporting reference allele",Gene_expression,Detection,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction,"submit(0:no; 1:yes)"
};

#print OUT "dbSNP(0:no; 1:yes),Gene_name,Chromosome,Start_position (B36),End_position (B36),Reference_allele,Variant_allele,# of genomic reads supporting reference allele,# of cDNA reads supporting reference allele,# of genomic reads supporting variant allele,# of cDNA reads supporting variant allele,Gene_expression,Detection,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction\n";
 while(<IN>){
 next if(/dbSNP/);
 chomp(); 
 my $line=$_;
 my $pph_prediction="NULL";
 my ($dbsnp,$chromosome,$start,$end,$al1,$al1_read1,$al1_read2,$al2,$al2_read1,$al2_read2,$gene,$transcript,$strand,$trv_type,$c_position,$pro_str,$polyphen,$gene_exp,$gene_det,$rgg_id) =  split(/,/)  ; 
 print "check  $chromosome,$start,$end,$al1,$al2,$transcript...............\n";
#only check flanking region as 10k bp
 if($trv_type=~/flank/) {
	 my ($tr) = MPSampleData::Transcript->search("transcript_name"=>$transcript);
	next unless(($tr->transcript_start>$start && $start>=$tr->transcript_start-10000 )||($tr->transcript_stop<$start && $start<=$tr->transcript_stop+10000 ));
  }
  $gene_hash->{$gene}=MG::Analysis::VariantAnnotation->get_gene_expression($sth,$gene) unless(defined $gene_hash->{$gene});
#check whether submitted or not
  my $submit;
  if(exists $submitted->{"$chromosome,$start,$end"} &&  $submitted->{"$chromosome,$start,$end"}==1) {$submit=1;}
  else {$submit=0;}
  print OUT "$dbsnp,$gene,$chromosome,$start,$end,$al1,$al1_read1,$al1_read2,$al2,$al2_read1,$al2_read2,",$gene_hash->{$gene}->{exp},",",$gene_hash->{$gene}->{det},",$transcript,$strand,$trv_type,$c_position,$pro_str,$pph_prediction,$submit,$rgg_id\n";
}

 
print "final finished!\n";
 
close(IN);
close(OUT);

 

#subrutine


# check if submitted or -+20bp
sub check_submitted{
 open (FILTER, ">$options{'file'}.filted") or die "Can't open $options{'file'}.filted. $!";
 open (IN, "<$options{'file'}.prioritized") or die "Can't open $options{'file'}.prioritized. $!";
 while(<IN>){print FILTER $_; last;}
 while(<IN>){
  my $grep=0;
  chomp();
  my @sp=split(/,/);
  open (CHECK, "</gscuser/xshi/work/AML_SNP/AML_SNP_set.091507.txt") or die "Can't open /gscuser/xshi/work/AML_SNP/AML_SNP_set.091507.txt. $!";
  while(<CHECK>) {last;}
  while(<CHECK>) {
    chomp();
    my @fi=split(/,/);
    if(lc($fi[1]) eq lc($sp[1])&&($sp[2]>=$fi[2]-20&&$sp[3]<=$fi[3]+20)) {
	{$grep=1;last;}
    }
  }
  close(CHECK);
  print FILTER join(",",@sp),"\n" if($grep==0);
 }
 close(IN); 
 close(FILTER);
  
}

#$HeadURL$
#$Id$
