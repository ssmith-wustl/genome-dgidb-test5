package Genome::Model::Tools::BreakpointPal;

use strict;
use warnings;
use Genome;
use GSCApp;

class Genome::Model::Tools::BreakpointPal {
    is => 'Command',                    
    has => [ # specify the command's properties (parameters) <--- 
	     breakpoint_id    => {
		 type         => 'String',
		 doc          => "give the breakpoint_id in this format chr11:36287905-36288124",
	     },
	     bp_flank         => {
		 type         => 'Number',
		 doc          => "give the number of bases you'd like for fasta's around the breakpoint [Default value is 300]",
		 is_optional  => 1,

	     },
	     pal_threshold    => {
		 type         => 'Number',
		 doc          => "give the pal threshold you'd like to use in your pal [Default value is 100]",
		 is_optional  => 1,

	     },

	     ],
    
    
};


sub help_brief {                            # keep this to just a few words <---
    "This tool will make three fasta files from the Human NCBI build 36based on you breakpoint id and run a pal -all on them."                 
}

sub help_synopsis {                         # replace the text below with real examples <---
    return <<EOS

gt break-point-pal --breakpoint-id chr11:36287905-36288124
 
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

running this breakpoint id with the default options
gt breakpoint-pal --breakpoint-id chr11:36287905-36288124

is the same as running

gt breakpoint-pal --breakpoint-id chr11:36287905-36288124 --bp-flank 300 --pal-threshold 100


which will result in 3 fasta files

chr11:36287905-36288124.BP1-2.fasta      is the fasta from 36287905 to 36288124 on chr11
chr11:36287905-36288124.BP1.300.fasta    300 flank either side of BP1 "36287905" 
      (5prime => 36287604-36287904 and 3prime => 36287905-36288205)
chr11:36287905-36288124.BP2.300.fasta    300 flank either side of BP2 "36288124" 
      (5prime => 36287823-36288123 and 3prime => 36288124-36288424)

and the result from the pal
chr11:36287905-36288124.BP1-2.fasta.BP2.pal100.ghostview

"pal -files chr12:36287905-36288124.BP1-2.fasta chr12:36287905-36288124.BP1.300.fasta chr12:36287905-36288124.BP2.300.fasta -s 100 -all -out chr12:36287905-36288124.BP1-2.fasta.BP2.pal100.ghostview"

EOS
}


sub execute {                               # replace with real execution logic.
    my $self = shift;
    my $bp_id = $self->breakpoint_id;
    my ($chromosome,$breakpoint1,$breakpoint2);

    unless ($bp_id) {die "please provide the breakpoint id\n";}
    if ($bp_id =~ /chr([\S]+)\:(\d+)\-(\d+)/) { 
	$chromosome = $1;
	$breakpoint1 = $2;
	$breakpoint2 = $3;
    } else { die "please check the format of your breakpoint id\n"; }

    
    my $flank = $self->bp_flank;
    unless ($flank) { $flank = 300; }
    my $pal_s = $self->pal_threshold;
    unless ($pal_s) { $pal_s = 100; }


    my $bpr = $breakpoint2 - $breakpoint1;
    unless ($bpr >= $flank) { warn "Breakpoint region is $bpr, less than your flank, your BP1 and BP2 fasta have sequence from overlapping coordinates\n"; }
    
####Fasta1
    
    my $fasta1 = "$bp_id.BP1-2.fasta";
    open(FA,">$fasta1");
    
    my $fasta1_seq = &get_ref_base($chromosome,$breakpoint1,$breakpoint2);
    
    print FA qq(>$fasta1 NCBI Build 36, Chr:$chromosome, Coords $breakpoint1-$breakpoint2, Ori (+)\n);
    print FA qq($fasta1_seq\n);
    
    close(FA);
    
####Fasta2
    
    my $fasta2 = "$bp_id.BP1.$flank.fasta";
    open(FA2,">$fasta2");
    
    my $lt_stop1 = $breakpoint1 - 1;
    my $lt_start1 = $lt_stop1 - $flank;
    my $fasta2_lt_seq = &get_ref_base($chromosome,$lt_start1,$lt_stop1);
    
    print FA2 qq(>BP1.5prime.fasta $flank.$fasta1 NCBI Build 36, Chr:$chromosome, Coords $lt_start1-$lt_stop1, Ori (+)\n);
    print FA2 qq($fasta2_lt_seq\n);
    
    my $rt_start1 = $breakpoint1;
    my $rt_stop1 = $rt_start1 + $flank;
    my $fasta2_rt_seq = &get_ref_base($chromosome,$rt_start1,$rt_stop1);
    
    print FA2 qq(>BP1.3prime.fasta $flank.$fasta1 NCBI Build 36, Chr:$chromosome, Coords $rt_start1-$rt_stop1, Ori (+)\n);
    print FA2 qq($fasta2_rt_seq\n);
    
    close(FA2);
    
######Fasta3
    
    my $fasta3 = "$bp_id.BP2.$flank.fasta";
    open(FA3,">$fasta3");
    
    my $lt_stop2 = $breakpoint2 - 1;
    my $lt_start2 = $lt_stop2 - $flank;
    my $fasta3_lt_seq = &get_ref_base($chromosome,$lt_start2,$lt_stop2);
    
    print FA3 qq(>BP2.5prime.fasta $flank.$fasta1 NCBI Build 36, Chr:$chromosome, Coords $lt_start2-$lt_stop2, Ori (+)\n);
    print FA3 qq($fasta3_lt_seq\n);
    
    my $rt_start2 = $breakpoint2;
    my $rt_stop2 = $rt_start2 + $flank;
    my $fasta3_rt_seq = &get_ref_base($chromosome,$rt_start2,$rt_stop2);
    
    print FA3 qq(>BP2.3prime.fasta $flank.$fasta1 NCBI Build 36, Chr:$chromosome, Coords $rt_start2-$rt_stop2, Ori (+)\n);
    print FA3 qq($fasta3_rt_seq\n);
    
    close(FA3);
    
######PAL
    
    print qq(running\n\tpal -files $fasta1 $fasta2 $fasta3 -s $pal_s -all -out $fasta1.BP2.pal$pal_s.ghostview\n);
    system qq(pal -files $fasta1 $fasta2 $fasta3 -s $pal_s -all -out $fasta1.BP2.pal$pal_s.ghostview);
    
}


######primer3 

sub get_ref_base {

#used to generate the refseqs;
    use Bio::DB::Fasta;
    my $RefDir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
    my $refdb = Bio::DB::Fasta->new($RefDir);

    my ($chr_name,$chr_start,$chr_stop) = @_;
    my $seq = $refdb->seq($chr_name, $chr_start => $chr_stop);
    $seq =~ s/([\S]+)/\U$1/;

    if ($seq =~ /N/) {warn "your sequence has N in it\n";}

    return $seq;
    
}

