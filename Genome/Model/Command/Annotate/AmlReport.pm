package Genome::Model::Command::Annotate::AmlReport;

use strict;
use warnings;

use above "Genome"; 

class Genome::Model::Command::Annotate::AmlReport
{
    is => 'Command',                       
    has => 
    [ 
    db_name => { type => 'String', doc => "?", is_optional => 0 },
    file => { type => 'String', doc => "?", is_optional => 0 },
    ], 
};

use IO::File;
use MG::Analysis::VariantAnnotation;
use MPSampleData::DBI;
use MPSampleData::ReadGroupGenotype;

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

sub help_detail {
    return <<EOS 
This is a dummy command.  Copy, paste and modify the module! 
CHANGE THIS BLOCK OF TEXT IN THE MODULE TO CHANGE THE HELP OUTPUT.
EOS
}

sub execute { 
    my $self = shift;

   MPSampleData::DBI->connect($self->db_name);

   my $file = $self->file;
   my $fh = IO::File->new("< $file");
   $self->error_message("Can't open file ($file): $!")
       and return unless $fh;

   my $err_file = "$file.error";
    open (ERROR,"> $err_file") or die "Can't open $err_file\: $!";
   my $out_file = "$file.out";
    open (OUT, "> $out_file") or die "Can't open $out_file\: $!";
    print OUT "dbSNP(0:no; 1:yes),Chromosome,Start_position (B36),End_position (B36),Reference_allele,# of cDNA reads supporting reference allele,# of genomic reads supporting reference allele,Variant_allele,# of cDNA reads supporting variant allele,# of genomic reads supporting variant allele,Gene_name,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction,Gene_expression,Detection\n";

    while ( my $id = $fh->getline )
    {
        chomp $id;
        my $genotype = MPSampleData::ReadGroupGenotype->retrieve($id);
        # check!

=pod
        print join
        (
            "\t",
            map(
                { defined($_) ? $_ : 0 }
                $genotype->chrom_id->chromosome_name,
                $genotype->start,
                $genotype->end,
                $genotype->allele1,
                $genotype->allele2,
                $genotype->allele1_type,
                $genotype->allele2_type,
                $genotype->num_reads1,
                $genotype->num_reads2,
            )
        ), "\n";
=cut 

        my ($chromosome,$start,$end,$allele1,$allele1_read1,$allele1_read2,$allele2,$allele2_read1,$allele2_read2,$allele1_type,$allele2_type) ; 
       ( $chromosome,$start,$end,$allele1,$allele2,$allele1_type,$allele2_type,$allele1_read1,$allele2_read1) =  (
            $genotype->chrom_id->chromosome_name,
                $genotype->start,
                $genotype->end,
                $genotype->allele1,
                $genotype->allele2,
                $genotype->allele1_type,
                $genotype->allele2_type,
                $genotype->num_reads1,
                $genotype->num_reads2
            );

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
                unless(@trs) {print ERROR "no result: $id\n"; next;}

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

    print "final finished!\n";

    close(ERROR);
    close(OUT);

    $fh->close;

    return 1;
}

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
