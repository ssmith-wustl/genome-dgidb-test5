#!/gsc/bin/perl


use strict;
use warnings;

use Getopt::Long;
use Carp;
use MPSampleData::DBI;
use MPSampleData::ExternalGeneId;
#use lib '/gscuser/xshi/svn/mp';
use MG::Analysis::VariantAnnotation;

my %options = ( 'file'         => undef,
		 
		 
                'dev'         => undef,
		 
 	     );
 
GetOptions( 'file=s'       => \$options{'file'},
	   
	    
           'devel=s'       => \$options{'dev'},
	  
	);
 
unless(defined($options{'dev'}))  {
    croak "usage $0 --dev <database sample_data/sd_test..>";
}
MPSampleData::DBI->set_sql(change_db => qq{use $options{dev}});
MPSampleData::DBI->sql_change_db->execute;
#my $gene_info; 
#my $gene_hash;
# my $chrom_ids = MG::Analysis::VariantAnnotation->map_chromid_chromosome ;
# my $gene_list;
#  open (GENELIST, "<$ARGV[0]") or die "Can't open $ARGV[0]. $!";
# while(<GENELIST>){
# 	chomp();
# 	$gene_list->{$_}=1;
# }
#  close(GENELIST);

open (IN, "<$options{'file'}") or die "Can't open $options{'file'}. $!";
open (ERROR,">$options{'file'}.error") or die "cant' open $options{'file'}.error $!";
open (OUT, ">$options{'file'}.out") or die "Can't open $options{'file'}.out. $!";
my @header = (  "dbSNP(0:no; 1:yes)",
                "Chromosome",
                "Start_position (B36)",
                "End_position (B36)",
                "Reference_allele",
                "# of cDNA reads supporting reference allele",
                "# of genomic reads supporting reference allele",
                "Variant_allele",
                "# of cDNA reads supporting variant allele",
                "# of genomic reads supporting variant allele",
                "Gene_name",
                "Ensembl_transcript_id",
                "Transcript_stranding",
                "Variant_type",
                "Transcript_position",
                "Amino_acid_change",
                "Polyphen_prediction",
                "Gene_expression",
                "Detection",
            );
print OUT join q{,}, @header;
print OUT "\n";

while(<IN>){
    chomp(); 
    my $line=$_;
    my ($chromosome,$start,$end,$allele1,$allele1_read1,$allele1_read2,$allele2,$allele2_read1,$allele2_read2,$allele1_type,$allele2_type) ; 
#   ($chrom,$start,$end,$allele1,$allele1_read1,$allele1_read2,$allele2,$allele2_read1,$allele2_read2,$allele1_type,$allele2_type) =  split(/\t/) if($options{'gr'}==1); 
    ($chromosome,$start,$end,$allele1,$allele2,$allele1_type,$allele2_type,$allele1_read1,$allele2_read1) =  split(/\t/)  ; 

    print "check   $chromosome,$start,$end,$allele1,$allele2 ...............\t";
    next if($allele1_type eq 'ref' && $allele2_type eq 'ref');	
    my $self=MG::Analysis::VariantAnnotation->new(type=>$allele2_type,chromosome=>$chromosome,start=>$start,end=>$end,filter=>1);
    my $dbsnp=$self->check_dbsnp;
# 	next if($dbsnp==1);
    $allele1_read1=0 if(!defined $allele1_read1);
    $allele1_read2=0 if(!defined $allele1_read2);
    $allele2_read1=0 if(!defined $allele2_read1);
    $allele2_read2=0 if(!defined $allele2_read2);

    #get reference allele
    my $ref_a=$self->get_referrence_allele($chromosome,$start,$end);

    if($allele1_type eq 'ref'&& $allele1 ne $ref_a) { 
        print ERROR "reference allele not match:$chromosome,$start,$end,$allele1,$allele1_read1,$allele2,$allele2_read1,$allele1_type,$allele2_type\n"; 
        next;
    }
    my (@allele);
    if($allele1_type eq 'SNP' && $allele2_type eq 'SNP'){
        push(@allele,"$ref_a,0,0,$allele1,$allele1_read1,$allele1_read2") if($allele1 ne $allele2);	
        push(@allele,"$ref_a,0,0,$allele2,$allele2_read1,$allele2_read2");	
    }
    else{
        push(@allele,"$allele1,$allele1_read1,$allele1_read2,$allele2,$allele2_read1,$allele2_read2");	
    }

    while(my $allele=shift @allele){
        my ($al1,$al1_read1,$al1_read2,$al2,$al2_read1,$al2_read2)=split(",",$allele);
        print " [anno $al1,$al2] ";
        my $result=$self->annotate(allele1=>$al1,allele2=>$al2); 
#get the annotation result
        foreach my $gene (keys %{$self->{annotation}}){
            my @trs;
            if($self->{filter} eq 1) {
                push(@trs,$self->{annotation}->{$gene}->{choice}) if(exists $self->{annotation}->{$gene}->{choice} && defined $self->{annotation}->{$gene}->{choice});
            }
            else {
                @trs=keys %{$self->{annotation}->{$gene}->{transcript}} if(exists $self->{annotation}->{$gene}->{transcript} && defined $self->{annotation}->{$gene}->{transcript});  
            } 
            unless(@trs) {print ERROR "no result:$line\n"; next;}

            foreach my $transcript (@trs) {
# 			my $pph_prediction="NULL"; 
                my @fields = (  $dbsnp,
                                $chromosome,
                                $start,
                                $end,
                                $al1,
                                $al1_read1,
                                $al1_read2,
                                $al2,
                                $al2_read1,
                                $al2_read2,
                                $gene,
                                $transcript,
                                $self->{annotation}->{$gene}->{transcript}->{$transcript}->{strand},
                                $self->{annotation}->{$gene}->{transcript}->{$transcript}->{trv_type},
                                "c.".$self->{annotation}->{$gene}->{transcript}->{$transcript}->{c_position},
                                $self->{annotation}->{$gene}->{transcript}->{$transcript}->{pro_str},
                                "NULL",
                                0,
                                0,
                            );
                print OUT join q{,}, @fields;
                print OUT "\n";
            }
        }
        for my $error_count (keys %{$self->{error}}){
            print ERROR $self->{error}->{$error_count},"\n"; 
        }


    }
    print "\n";	
}

#MG::Analysis::VariantAnnotation->finish;

print "final finished!\n";

close(ERROR);
close(OUT);

# `perl /gscuser/xshi/work/AML_SNP/get_maq_num_reads.pl --dev sd_test --input $options{'file'}.prioritized --output $options{'file'}.prioritized.maqgt --list1 maq-wugsc-solexa-hg-dna_2_55 --pileup /gscuser/xshi/work/AML_SNP/maq_genotype/run124u567_mg_cnosv_q30_hg71.lst`;
# check_submitted() if(defined  $options{'checksubm'} && $options{'checksubm'}==1);

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Annotate/AmlReport.t/aml_snp_report_paralle_module.pl $
#$Id: aml_snp_report_paralle_module.pl 33444 2008-04-04 20:13:57Z ebelter $
