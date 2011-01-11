package Genome::Model::Tools::Somatic::IdentifyDnpAdv;

#use strict;
use warnings;

use Genome;
use Genome::Info::IUB;
use IO::File;
use POSIX;
use Sort::Naturally;

class Genome::Model::Tools::Somatic::IdentifyDnpAdv {
    is => 'Command',
    has => [
    input_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => 'List of sites in input file 1_based file format to look for DNPs. This must be sorted by chromosome and coordinate.',
        default => '',
    },
    anno_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => 'List of sites after looking for DNPs and ready for annotator, in 1_based file format. This must be sorted by chromosome and coordinate.',
        default => '',
    },
    bed_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => 'List of sites after looking for DNPs and ready for fast-tiering, in bed format. This must be sorted by chromosome and coordinate.',
        default => '',
    },
    proportion => 
    {
        type => 'Float',
        is_optional => 1,
        default => 0.1,
        doc => 'Proportion of reads supporting the DNP required for the site to be considered a DNP',
    },
    bam_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => 'File from which to retrieve reads. Must be indexed.',
    }

    ]
};
#Code should operate as follows
#Scan the snp file
#Upon finding adjacent snps
#retrieve reads for the two snps
#Check and see if they are in cis ie in the same read together

sub execute {
    my $self=shift;
    $DB::single = 1;
    my $snp_file = $self->input_file;

    #TODO Add checks on the files and architecture
    unless (POSIX::uname =~ /64/) {
        $self->error_message("This script requires a 64-bit system to run samtools");
        return;
    }

    unless(-e $self->bam_file && !-z $self->bam_file) {
        $self->error_message($self->bam_file . " does not exist or is of zero size");
        return;
    }

    my $fh = IO::File->new($snp_file, "r");
    unless($fh) {
        $self->error_message("Couldn't open $snp_file: $!"); 
        return;
    }

    my $last_chr = undef;
    my $last_stop = undef;
    my $last_pos = undef;
    my $last_ref = undef;
    my $last_cns = undef;
    my $last_type = undef;
    my @lines = (); #line buffer to store last few lines


    my %SNP={}; #my %NNP={}; my %chr={}; my %pos={};
    
#the following logic assumes that you have a single position per line

    # looking for candidate NNP sites 
    while(my $line = $fh->getline) {
      chomp $line;
      my ($chr, $pos,$stop, $ref, $cns, $type, @rest) = split /\t/, $line;
      print "$line\n" if ($line =~ m/43366241|43366240/);
      if ($last_chr && $last_pos){
          if ($last_chr eq $chr){
              if (($pos-$last_stop)==1){
                  $last_stop=$stop;
                  $last_ref=$last_ref.$ref;
                  $last_cns=$last_cns.$cns;
                  $last_type++;
                  print "$chr:$last_stop,$last_type\t";    
              }else{              
                  $SNP{$last_chr}{$last_pos}{$last_stop}{$last_ref}{$last_cns}=$last_type;
                  $last_chr = $chr;
                  $last_pos = $pos;
                  $last_stop= $stop;
                  $last_ref = $ref;
                  $last_cns = $cns;
                  $last_type=1;
              } 
          }else{
              $SNP{$last_chr}{$last_pos}{$last_stop}{$last_ref}{$last_cns}=$last_type;
              $last_chr = $chr;
              $last_pos = $pos;
              $last_stop= $stop;
              $last_ref = $ref;
              $last_cns = $cns;
              $last_type=1;
           }
       }else{
              $last_chr = $chr;
              $last_pos = $pos;
              $last_stop= $stop;
              $last_ref = $ref;
              $last_cns = $cns;
              $last_type=1;
       } 
   }
   $SNP{$last_chr}{$last_pos}{$last_stop}{$last_ref}{$last_cns}=$last_type;
   $fh->close;

   #sort candidate variants
    my $n=0; my @candidate=();
    for my $chr (nsort keys %SNP){
        #    for my $chr (sort { length $a <=> length $b || $a cmp $b } keys %SNP){
        for my $pos (sort {$a <=>$b} keys %{$SNP{$chr}}){
            for my $stop (sort { $a cmp $b } keys %{$SNP{$chr}{$pos}}){
                   for  my $ref (sort { $a cmp $b } keys %{$SNP{$chr}{$pos}{$stop}}){
                       for  my $cns (sort { $a cmp $b } keys %{$SNP{$chr}{$pos}{$stop}{$ref}}){
                              my $type = $SNP{$chr}{$pos}{$stop}{$ref}{$cns};
                              if ($type >1){
                                  push @candidate,"$chr\t$pos\t$stop\t$ref\t$cns\t$type";
                                  $n++;
                              }else{
                                  push @candidate, "$chr\t$pos\t$stop\t$ref\t$cns\t$type";
                              }
                        }
                   }
              }
         }
    }
    print "\ncandidate number: $n\n";
    
    # Above code passed the test;
    # following code include IUB processing, it need to be further tested

    my @result=undef;
    for my $candidate (@candidate){
        my ($chr, $pos, $stop, $ref, $cns, $type) = split /\t/, $candidate;
        my (@dnp,@dnp1,@dnp2,@snp)=(undef,undef,undef,undef);
        if ($type==1) { 
            my @var1=Genome::Info::IUB::variant_alleles_for_iub($ref,$cns);
            for my $var1(@var1){
                if ($var1 ne $ref) {
                 push @result, "$chr\t$pos\t$stop\t$ref\t$var1\tSNP\n";
                }
            }
        }elsif ($type==2){
            @dnp=undef;
            my $ref1=substr($ref,0,1); 
            my $ref2=substr($ref,1,1);
            my $cns1=substr($cns,0,1);
            my $cns2=substr($cns,1,1);
            my @var1=Genome::Info::IUB::variant_alleles_for_iub($ref1,$cns1); 
            my @var2=Genome::Info::IUB::variant_alleles_for_iub($ref2,$cns2); 
            my $stop1=$pos+1;         
            for my $var1 (@var1){
                for my $var2 (@var2){
                   if ($self->is_dnp($chr,$pos,$var1,$stop1,$var2)){
                       if ($ref ne $var1.$var2){
                          my $dnp= "$chr\t$pos\t$stop1\t$ref\t$var1$var2\tDNP\n"; 
                          # print $dnp;
                          push @dnp, $dnp; 
                       }
                   }
               }
            }
            if (@dnp){
                for my $dnp (@dnp){
                    push @result, $dnp;
                }
            }else{
                push @result, "$chr\t$pos\t$pos\t\t$ref1\t$cns1\tSNP\n";
                push @result, "$chr\t$stop1\t$stop1\t$ref2\t$cns2\tSNP\n";
            }
        }elsif ($type ==3 ){
            my @dnp1=undef; my @dnp2=undef; my @snp=undef;
            my $ref1=substr($ref,0,1); 
            my $ref2=substr($ref,1,1); 
            my $ref3=substr($ref,2,1);
            my $cns1=substr($cns,0,1);
            my $cns2=substr($cns,1,1);
            my $cns3=substr($cns,2,1); 
            my @var1=Genome::Info::IUB::variant_alleles_for_iub($ref,$cns1); 
            my @var2=Genome::Info::IUB::variant_alleles_for_iub($ref,$cns2); 
            my @var3=Genome::Info::IUB::variant_alleles_for_iub($ref,$cns3);
            my $stop1=$pos+1; my $stop2=$pos+2; 
            for my $var1 (@var1){
                for my $var2 (@var2){
                   if ($self->is_dnp($chr,$pos,$var1,$stop1,$var2)){
                       if ( $ref1.$ref2 ne $var1.$var2){ 
                           my $dnp1= "$chr\t$pos\t$stop1\t$ref1$ref2\t$var1$var2\tDNP\n";
                           push @dnp1,$dnp;
                       }
                   }
               }
            } 
            for my $var2 (@var2){
                for my $var3 (@var3){
                   if ($self->is_dnp($chr,$stop1,$var2,$stop2,$var3)){
                       if ($ref2.$ref3 ne $var2.$var3){ 
                           my $dnp2="$chr\t$stop1\t$stop2\t$ref2$ref3\t$var2$var3\tDNP\n"; 
                           push @dnp2,$dnp2;
                       }
                   }
               }
            }
            @dnp=undef; @tnp=undef;@snp=undef;
            if(@dnp1 && @dnp2){
                   #FIXME Assume double dnp is TNP if the middle nucleotide is same. 
                   #Need to remove the false positive case, such as AT and TG are on different reads
                   #TODO sort the @tnp,@dnp,@snp together before print out. It now print out SNP>DNP>TNP
                   for my $dnp1(@dnp1){
                       for my $dnp2(@dnp2){
                           my ($chr1,$pos1,$stop1,$ref1,$var1,$type1)=$dnp1;
                           my ($chr2,$pos2,$stop2,$ref2, $var2,$type2)=$dnp2;
                           my $var1_2=substr($var1,1,1);
                           my $var2_1=substr($var2,0,1);
                           my $var2_2=substr($var2,1,1);
                           if ($var1_2 eq $var2_1 && $ref ne $var1.$var2_2){
                               my $tnp_var=substr($var1,0,1).$var1_2.substr($var,1,1);
                               my $tnp_ref=substr($ref1,0,1).substr($ref1,0,1).substr($ref1,1,1);
                               my $tnp="$chr\t$pos1\t$stop2\t$tnp_ref\t$tnp_var\tTNP\n";
                               push @tnp,$tnp; 
                           }else{
                               push @dnp,$dnp1;
                               push @dnp,$dnp2;
                           }
                       }
                   }
            }elsif (@dnp1 || @dnp2){
                # only @dnp1 + SNP survive
                if (@dnp1){
                    @dnp=@dnp1;
                    my $snp="$chr\t$stop2\t$stop2\t$ref3\t$cns3\tSNP\n";
                    push @snp, $snp;
                }elsif(@dnp2){ 
                    @dnp=@dnp2; 
                    my $snp="$chr\t$pos\t$pos\t$ref1\t$cns1\tSNP\n";
                    push @snp, $snp;
                }
            }else{
                # only 3 SNPs independently exists
                my $snp="$chr\t$pos\t$pos\t$ref1\t$cns1\tSNP\n";
                push @snp, $snp;
                $snp="$chr\t$stop1\t$stop1\t$ref2\t$cns2\tSNP\n";
                push @snp, $snp;
                $snp="$chr\t$stop2\t$stop2\t$ref3\t$cns3\tSNP\n"; 
                push @snp, $snp;
            }
            my $new=undef;
            if (@snp){
                for $new (@snp){
                    push @result,$new;
                }
            }
            if (@dnp){
                for $new (@dnp){
                    push @result, $new;
                }
            }
            if (@tnp){
                for $new (@tnp){
                    push @result, $new;
                }
            }
        }elsif ($type > 3){ 
            # FIXME CANNOT handle SNPs >3, make it back to SNPs
            $self->error_message("Unable to process more than TNP\n$candidate\, make it back to SNPsn");
            my ($CHR,$START,$STOP,$REF,$VAR,$TYPE)=split/\t/,$candidate;
            my $current=$START; my $n=0;
            while ( ($current+$n) < $STOP){
                my $start =$current+$n;
                my $cns=substr($VAR,$n,1);
                my $ref=substr($VAR,$n,1);
                my @var1=Genome::Info::IUB::variant_alleles_for_iub($ref,$cns);
                for my $var1(@var1){
                    if ($var1 ne $ref) {
                        push @result, "$chr\t$pos\t$stop\t$ref\t$var1\tSNP\n";
                    }
                }
                $n++;
            }
#            push @result,"$candidate\n";
#            if ($self->is_dnp($chr, $last_pos,$last_cns,$pos,$cns)){
#            }
        }
    }

    # print output file
   
    my $bedfile = IO::File->new($self->bed_file, "w");
    unless($bedfile) {
        $self->error_message("Unable to open " . $self->bed_file . " for writing. $!");
        die;
    }
    
    my $annofile = IO::File->new($self->anno_file, "w");
    unless($annofile) {
        $self->error_message("Unable to open " . $self->anno_file . " for writing. $!");
        die;
    }    

    for my $line (@result){
        my ($chr, $start, $stop, $ref, $var, $type) = split /\t/, $line;
        # ANNOFILE: both the start and the stop are 1_based
        print $annofile "$line";
        # BEDFILE: the start is 0_based, and the stop is 1_based
        $start=$start-1;
        print $bedfile "$chr\t$start\t$stop\t$ref\t$var\t$type\n";
    }

    $bedfile->close; $annofile->close;
}

1;

sub help_brief {
    "Scans an annotation file, finds adjacent sites and then identifies if these are DNPs."
}

sub help_detail {
    <<'HELP';
This is a simple script which operated by identifying adjacent sites in a SORTED annotation file (really, just chr, start, stop, ref, cns, and type are need in that order). And then it breadk the IUB code and check all the possible recombination and determine if the alleles are linked in the same reads. If so, wrapping them into a single DNP and TNP event. The other sites are simply printed as is. Currently, only DNPs and TNPs are examined. Any continus SNPs sites > 3 will still be handled as SNPs. The input file was intended to be the pre-annotation "adapted file" of SNVs from the somatic pipeline file and, therefore, should NOT contain indels.The output is bed_format, that can be put into fast-tiering  
HELP
}

#I can't say why this is just a wrapper for the other program
sub is_dnp {
    my ($self, $chr, $pos1, $base1, $pos2, $base2) = @_;
    return $self->_determine_dnp_from_bam_reads($self->bam_file,$chr,$pos1,$base1,$pos2,$base2);
}

#This grabs the reads overlapping the positions
#and checks to see if they contain both potential DNP bases
sub _determine_dnp_from_bam_reads {
    my ($self, $alignment_file, $chr, $pos1, $base1, $pos2, $base2) = @_;
    unless(open(SAMTOOLS, "samtools view $alignment_file $chr:$pos1-$pos2 |")) {
        $self->error_message("Unable to open pipe to samtools view");
        return;
    }
    my ($reads, $reads_supporting_dnp) = (0,0);
    while( <SAMTOOLS> ) {
        chomp;
        my ($qname, $flag, $rname, $pos_read, $mapq, $cigar, $mrnm, $mpos, $isize, $seq, $qual, $RG, $MF, @rest_of_fields) = split /\t/;
        next if($mapq == 0); #only count q1 and above

        my $offset1 = $self->_calculate_offset($pos1, $pos_read, $cigar);
        next unless defined $offset1; #skip deletions
        my $offset2 = $self->_calculate_offset($pos2, $pos_read, $cigar);
        next unless defined $offset2; #skip deletions
        $reads++;
        
        if(uc(substr($seq,$offset1,1)) eq uc($base1) && uc(substr($seq,$offset2,1)) eq uc($base2)) {
            $reads_supporting_dnp++;
        }


    }
    unless(close(SAMTOOLS)) {
        $self->error_message("Error running samtools");
        return -1;
    }
    if($reads_supporting_dnp/$reads > $self->proportion) {
        return 1;
    }
    else {
        return 0;
    }
}

#this calculates the offset of a position into a seqeunce string based on the CIGAR string specifying the alignment
#these are some tests used to test if I got this right.

#use Test::Simple tests => 2;
#my $fake_read_seq = "ACTATCG";
#my $fake_read_pos = 228;
#my $fake_cigar = "3M1D4M";
##
#my $offset = calculate_offset(231,$fake_read_pos, $fake_cigar);
#ok(!defined($offset));
#$offset = calculate_offset(232,$fake_read_pos, $fake_cigar);
#ok(substr($fake_read_seq,$offset,1) eq "A");
#exit;
#
sub _calculate_offset { 
    my $self = shift;
    my $pos = shift;
    my $read_pos = shift;
    my $cigar = shift;
    my $current_offset=0;
    my $current_pos=$read_pos;
    my @ops = $cigar =~ m/([0-9]+)([MIDNSHP])/g; 
    OP:
    while(my ($cigar_len, $cigar_op) =  splice @ops, 0, 2 ) {
        my $new_offset;
        my $last_pos=$current_pos;
        if($cigar_op eq 'M') {
            $current_pos+=$cigar_len;
            $current_offset+=$cigar_len;
        }
        elsif($cigar_op eq 'I') {
            $current_offset+=$cigar_len;
        }
        elsif($cigar_op eq 'D') {
            $current_pos+=$cigar_len;

        }
        elsif($cigar_op eq 'N') {
            #this is the same as a deletion for returning a base from the read
            $current_pos += $cigar_len;
        }
        elsif($cigar_op eq 'S') {
            #soft clipping means the bases are in the read, but the position (I think) of the read starts at the first unclipped base
            #Functionally this is like an insertion at the beginning of the read
            $current_offset+=$cigar_len;
        }
        elsif($cigar_op eq 'H') {
            #hard clipping means the bases are not in the read and the position of the read starts at the first unclipped base
            #Shouldn't do anything in this case, but ignore it
        }
        else {
            die("CIGAR operation $cigar_op currently unsupported by this module");
        }
        if($pos < $current_pos && $pos >= $last_pos) {
            if($cigar_op eq 'M') {
                my $final_adjustment = $current_pos - $pos;
                return $current_offset - $final_adjustment;
            }
            else {
                return;
            }
        }
    }
    #position didn't cross the read
    return; 
}
    
