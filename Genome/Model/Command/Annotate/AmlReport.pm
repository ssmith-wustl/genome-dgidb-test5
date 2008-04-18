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

use Data::Dumper;
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

sub execute 
{ 
    my $self = shift;

    return $self->_annotate;
}

sub _annotate
{
    my $self = shift;

    MPSampleData::DBI->connect($self->db_name);

    my $file = $self->file;
    my $fh = IO::File->new("< $file");
    $self->error_message("Can't open file ($file): $!")
        and return unless $fh;

    my $err_file = "$file.error";
    open (ERROR,"> $err_file") or die "Can't open $err_file\: $!";

    my $outfile = "$file.out";
    my $outfh = IO::File->new("> $outfile");
    $self->error_message("Can't open file ($outfile): $!")
        and return unless $outfh;

    $outfh->print("dbSNP(0:no; 1:yes),Chromosome,Start_position (B36),End_position (B36),Reference_allele,# of cDNA reads supporting reference allele,# of genomic reads supporting reference allele,Variant_allele,# of cDNA reads supporting variant allele,# of genomic reads supporting variant allele,Gene_name,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction,Gene_expression,Detection\n");

    while ( my $id = $fh->getline )
    {
        chomp $id;
        my $genotype = MPSampleData::ReadGroupGenotype->retrieve($id);
        $self->error_message("Can't find read group genotype for id ($id)")
            and return unless 0;#$genotype;

        my (
            $chromosome_name,
            $start,
            $end,
            $allele1,
            $allele2,
            $allele1_type,
            $allele2_type,
            $allele1_read1,
            $allele2_read1
        ) =  (
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

        my ($allele1_read2, $allele2_read2);

        print "check   $chromosome_name,$start,$end,$allele1,$allele2 ...............\t";

        next if $genotype->allele1_type eq 'ref' and $genotype->allele2_type eq 'ref';	

        my $variant_annotation = MG::Analysis::VariantAnnotation->new
        (
            type => $allele2_type,
            chromosome => $chromosome_name,
            start => $start,
            end => $end,
            filter => 1,
        );

        my $dbsnp = $variant_annotation->check_dbsnp;

        $allele1_read1 = 0 unless defined $allele1_read1;
        $allele1_read2 = 0 unless defined $allele1_read2;
        $allele2_read1 = 0 unless defined $allele2_read1;
        $allele2_read2 = 0 unless defined $allele2_read2;

        my $ref_allele = $genotype->chrom_id->get_reference_allele($start, $end);
        if ( $allele1_type eq 'ref' and $allele1 ne $ref_allele ) 
        { 
            $self->error_message
            (
                sprintf
                (
                    'Reference allele (%s on chromosome %s from %d to %d) does not match given allele (%s)',
                    $ref_allele,
                    $chromosome_name,
                    $start,
                    $end,
                    $allele1,
                )
            );
            next;
        }




        my (@allele);
        if($allele1_type eq 'SNP' && $allele2_type eq 'SNP'){
            push(@allele,"$ref_allele,0,0,$allele1,$allele1_read1,$allele1_read2") if($allele1 ne $allele2);	
            push(@allele,"$ref_allele,0,0,$allele2,$allele2_read1,$allele2_read2");	
        }
        else{
            push(@allele,"$allele1,$allele1_read1,$allele1_read2,$allele2,$allele2_read1,$allele2_read2");	
        }

        while(my $allele=shift @allele){
            my ($al1,$al1_read1,$al1_read2,$al2,$al2_read1,$al2_read2)=split(",",$allele);
            print " [anno $al1,$al2] ";
            my $result=$variant_annotation->annotate(allele1=>$al1,allele2=>$al2); 
#get the annotation result

            #print Dumper($variant_annotation->{annotation});

            foreach my $gene (keys %{$variant_annotation->{annotation}}){
                my @trs;
                if($variant_annotation->{filter} eq 1) {
                    push(@trs,$variant_annotation->{annotation}->{$gene}->{choice}) if(exists $variant_annotation->{annotation}->{$gene}->{choice} && defined $variant_annotation->{annotation}->{$gene}->{choice});
                }
                else {
                    @trs=keys %{$variant_annotation->{annotation}->{$gene}->{transcript}} if(exists $variant_annotation->{annotation}->{$gene}->{transcript} && defined $variant_annotation->{annotation}->{$gene}->{transcript});  
                } 
                unless(@trs) 
                {
                    print ERROR "no result: $id\n";
                    next;
                }

                foreach my $transcript (@trs) {
# 			my $pph_prediction="NULL"; 
                    $outfh->print( join('', $dbsnp,",",$chromosome_name,",$start,$end,$al1,$al1_read1,$al1_read2,$al2,$al2_read1,$al2_read2,",$gene,",",$transcript,",",$variant_annotation->{annotation}->{$gene}->{transcript}->{$transcript}->{strand},",",$variant_annotation->{annotation}->{$gene}->{transcript}->{$transcript}->{trv_type},",c.",$variant_annotation->{annotation}->{$gene}->{transcript}->{$transcript}->{c_position},",",$variant_annotation->{annotation}->{$gene}->{transcript}->{$transcript}->{pro_str},",NULL,0,0\n") );
                }
            }
            for my $error_count (keys %{$variant_annotation->{error}}){
                print ERROR $variant_annotation->{error}->{$error_count},"\n"; 
            }
        }
        print "\n";	
    }

    print "final finished!\n";

    $fh->close;
    $outfh->close;

    close(ERROR);

    return 1;
}

1;

#$HeadURL$
#$Id$
