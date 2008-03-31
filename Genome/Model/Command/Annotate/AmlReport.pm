package Genome::Model::Command::Annotate::AmlReport;

use strict;
use warnings;

use above "Genome"; 

class Genome::Model::Command::Annotate::AmlReport
{
    is => 'Command',                       
    has => [ 
        file => { type => 'String', doc => "file", is_optional => 0, },
        dev  => { type => 'String', doc => "dev", is_optional => 0, },
    ], 
};

sub sub_command_sort_position { 12 }

sub help_brief {   
    "WRITE A ONE-LINE DESCRIPTION HERE"                 
}

sub help_synopsis { 
    return <<EOS
genome-model example1 --foo=hello
genome-model example1 --foo=goodbye --bar
genome-model example1 --foo=hello barearg1 barearg2 barearg3
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 
This is a dummy command.  Copy, paste and modify the module! 
CHANGE THIS BLOCK OF TEXT IN THE MODULE TO CHANGE THE HELP OUTPUT.
EOS
}

#sub create {                               # rarely implemented.  Initialize things before execute.  Delete unless you use it. <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # pre-execute checking.  Not requiried.  Delete unless you use it. <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute { 
    my $self = shift;

 my %options = ( 'file'         => $self->file,
            'dev'         => $self->dev,

        );

    if ( $options{dev} eq 'mysql' )
    {
        use Carp;

        use MPSampleData::DBI;
        use MPSampleData::ExternalGeneId;
#use lib '/gscuser/xshi/svn/mp';
        use MG::Analysis::VariantAnnotation;

               unless(defined($options{'dev'}))  {
            croak "usage $0 --dev <database sample_data/sd_test..>";
        }
        #MPSampleData::DBI->set_sql(change_db => "use $options{dev}");
        MPSampleData::DBI->set_sql(change_db => "use sd_test");
        MPSampleData::DBI->sql_change_db->execute;
    }
    elsif ( $options{dev} eq 'oracle' )
    {
        use MPSampleData::DBI;
        MPSampleData::DBI::myinit("dbi:Oracle:dwdev","mguser_dev"); #dev
        #MPSampleData::DBI::myinit("dbi:Oracle:dwrac","mguser_prd"); #prod
    }
    else
    {
        die "invalid dev: $options{dev}\n";
    }

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
    print OUT "dbSNP(0:no; 1:yes),Chromosome,Start_position (B36),End_position (B36),Reference_allele,# of cDNA reads supporting reference allele,# of genomic reads supporting reference allele,Variant_allele,# of cDNA reads supporting variant allele,# of genomic reads supporting variant allele,Gene_name,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction,Gene_expression,Detection\n";
    while(<IN>){
        chomp(); 
        my $line=$_;
        my ($chromosome,$start,$end,$allele1,$allele1_read1,$allele1_read2,$allele2,$allele2_read1,$allele2_read2,$allele1_type,$allele2_type) ; 
#   ($chrom,$start,$end,$allele1,$allele1_read1,$allele1_read2,$allele2,$allele2_read1,$allele2_read2,$allele1_type,$allele2_type) =  split(/\t/) if($options{'gr'}==1); 
        #($chromosome,$start,$end,$allele1,$allele2,$allele1_type,$allele2_type,$allele1_read1,$allele2_read1) =  split(/\t/)  ; 
        ($chromosome,$start,$end,$allele1,$allele2,$allele1_type,$allele2_type,$allele1_read1,$allele2_read1) =  split(/\s+/)  ; 

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
                    print OUT $dbsnp,",",$chromosome,",$start,$end,$al1,$al1_read1,$al1_read2,$al2,$al2_read1,$al2_read2,",$gene,",",$transcript,",",$self->{annotation}->{$gene}->{transcript}->{$transcript}->{strand},",",$self->{annotation}->{$gene}->{transcript}->{$transcript}->{trv_type},",c.",$self->{annotation}->{$gene}->{transcript}->{$transcript}->{c_position},",",$self->{annotation}->{$gene}->{transcript}->{$transcript}->{pro_str},",NULL,0,0\n";
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

# END OF SCRIPT
    return 1;
}

# `perl /gscuser/xshi/work/AML_SNP/get_maq_num_reads.pl --dev sd_test --input $options{'file'}.prioritized --output $options{'file'}.prioritized.maqgt --list1 maq-wugsc-solexa-hg-dna_2_55 --pileup /gscuser/xshi/work/AML_SNP/maq_genotype/run124u567_mg_cnosv_q30_hg71.lst`;
# check_submitted() if(defined  $options{'checksubm'} && $options{'checksubm'}==1);


#subrutine
# check if submitted or -+20bp
sub check_submitted{
    # added $self and options
    my $self = shift;
    my %options = ( 'file'         => $self->file,


        'dev'         => $self->dev,

    );


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

1;

#$HeadURL$
#$Id$
