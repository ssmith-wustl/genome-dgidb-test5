
package Genome::Model::Tools::Snp::Intersect;

use IO::File;
use strict;
use warnings;
use UR;

class Genome::Model::Tools::Snp::Intersect {
    is => 'Command',
    has => [ 
        count_only => { is => "Boolean", doc => "do not make files of intersection/differences, just count them" },
    ],
    doc => "intersect two variant lists (currently only SNPs are supported) and create intersection files"
};

sub help_synopsis {
    my $self = shift;
    return <<EOS;
gt snp intersect m1.snps m2.snps out-intersect.snps out-m1-only out-m2-only
intersection: 5602634
m1.snps only: 745011
m2.snps only: 687379

EOS
}

sub help_detail{
    return <<EOS;
Intersect two SNP  and produce a report on the intersection.

The lists should be sorted by chromosome, then position.
Numeric chromosomes should come, first in numeric order, followed by alphabetic chromosomes in alpha order.
Positions should be in numeric order.

The first output file contains data for all positions which intersect, and details from both files on the genotype called there.
The second output file contains positions only present in the first input file.
The third output file contains positions only present in the second input file.

The counts of the above are displayed after execution.
You can re-create this output with a simple:
    wc -l intersection.out f1.only f2.only

The information in the intersection file is then broken down by genotype intersection, and those counts are displayed.
You can re-create the output with a shell command later w/o re-running:
    cat intersection.out | columns 5 | sort |  uniq -c 

EOS
}

my %iub = (
    qw/
        A   A
        C   C
        G   G
        T   T
        R   AG  
        Y   CT  
        K   GT  
        M   AC  
        S   GC  
        W   AT  
        B   CGT 
        D   AGT 
        H   ACT 
        V   ACG 
        N   AGCT 
    /
);

my %iub_overlap;
for my $c1 (sort keys %iub) {
    for my $c2 (sort keys %iub) {
        my $n1 = $iub{$c1};
        my $n2 = $iub{$c2};
        my $c = 0;
        for $b (qw/A C G T/) {
            if ((index($n1,$b) != -1) and (index($n2,$b) != -1)) {
                $c++;
            }
        }
        $iub_overlap{$c1}{$c2} = $c;
        #print "$c1 ($n1)\t$c2 ($n2): $c\n";
    }
}

sub execute {
    my $self = shift;
    my $args = $self->bare_args;
    
    my $f1 = shift(@$args);
    my $f2 = shift(@$args);
    my $fi = shift(@$args);
    my $f1o = shift(@$args) || "$f1.only";
    my $f2o = shift(@$args) || "$f2.only";

    return $self->_intersect_lists($f1,$f2,$fi,$f1o,$f2o);
}

sub _intersect_lists {
    my ($self,$f1,$f2,$fi,$f1o,$f2o) = @_;

    my $h1 = IO::File->new($f1) or die "$f1: " . $!;
    my $h2 = IO::File->new($f2) or die "$f2: " . $!;

    my $count_only = $self->count_only;
    my ($xi,$x1,$x2);
    unless ($count_only) {
        $xi = IO::File->new(">$fi") or die $!;
        $x1 = IO::File->new(">$f1o") or die $!;
        $x2 = IO::File->new(">$f2o") or die $!;
    }

    my $n1 = 0;
    my $n2 = 0;
    my $ni = 0;    
    my %intersect_groups;

    no warnings;
    my ($v1,$c1,$p1,$r1,$g1,@t1);
    sub getf1() {
        $v1 = $h1->getline;
        if (defined $v1) {
            ($c1,$p1,$r1,$g1,@t1) = split(/\s+/,$v1);
            #print "f1: $c1 $p1 $g1\n";
        }
        else {
            $c1 = 'ZZZ';
        }
    }

    my ($v2,$c2,$p2,$r2,$g2,@t2);
    sub getf2() {
        $v2 = $h2->getline;
        if (defined $v2) {
            ($c2,$p2,$r2,$g2,@t2) = split(/\s+/,$v2);
            #print "f2: $c2 $p2 $g2\n";
        }
        else {
            $c2 = 'ZZZ';
        }
    }
    use warnings;

    sub printit {
        no warnings;
        my ($h,$c,$p,$g1,$t1,$r1,$g2,$t2,$r2)=@_;

        my $g1_het = ($g1 eq $iub{$g1} ? 'hom' : 'het');
        if ($g2) {
            my $g2_het = ($g2 eq $iub{$g2} ? 'hom' : 'het');
            my $m = $iub_overlap{$g1}{$g2};
            unless (defined $m) {
                die "no value for >$g1< >$g2<\n";
            }
            my $desc = ($g1 eq $g2 ? 'match' : 'miss').'-'.$g1_het.'-'.$g2_het.'-'.$m.'-base-overlap';
            $intersect_groups{$desc}++; 
            $h->print(join("\t",$c,$p,$g1,$g2,$desc,@$t1,$r1,":",@$t2,$r2),"\n");
        }
        else {
            $h->print(join("\t",$c,$p,$g1,$g1_het,@$t1,$r1),"\n");
        }
    }

    getf1();
    getf2();
    while ($v1 or $v2) {
        my $cc = chr_cmp($c1,$c2);
        if (($cc == -1) or ($cc == 0 and $p1 < $p2)) {
            $n1++;
            printit($x1,$c1,$p1,$g1,\@t1) unless $count_only;
            getf1();
        }
        elsif ($cc == 1 or ($cc == 0 and $p2 < $p1)) {
            $n2++;
            printit($x2,$c2,$p2,$g2,\@t2) unless $count_only;
            getf2();
        }
        elsif ($cc == 0 and $p1 == $p2) {
            $ni++;
            printit($xi,$c1,$p1,$g1,\@t1,$r1,$g2,\@t2,$r2) unless $count_only;
            getf1();
            getf2();
        }
        else {
            die "$v1\n$v2\n";
        }
    }
    print "$f1 only:\t$n1\n";
    print "$f2 only:\t$n2\n";
    print "intersection:\t$ni\n";
    for my $g (sort keys %intersect_groups) {
        print "\t", $g, ": ", $intersect_groups{$g}, "\n";
    }
    1;
}

sub chr_cmp {
    my ($a,$b) = @_;
    no warnings;
    if ($a == 0 and $b > 0) {
        return 1;
    }
    elsif ($b == 0 and $a > 0) {
        return -1;
    }
    elsif ($a == 0 and $b == 0) {
        return ($a cmp $b) 
    }
    else {
        return ($a <=> $b);
    }
}


1;

