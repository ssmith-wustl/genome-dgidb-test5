
package Genome::Model::Tools::Snp::Intersect;

use IO::File;
use strict;
use warnings;
use UR;

class Genome::Model::Tools::Snp::Intersect {
    is => 'Command',
    has => [ 
        intersect_output    => { is => 'FileName', is_optional => 1, 
                                    doc => 'instead of stdout, direct the intersection to this file' },
        f1_only_output      => { is => 'FileName', is_optional => 1, 
                                    doc => 'items present only in the first input should be dumped here' },
        f2_only_output      => { is => 'FileName', is_optional => 1, 
                                    doc => 'items present only in the second input should be dumped here' },
        detail              => { is => 'Boolean', 
                                    doc => 'instead of f1 data, the intersection should show cross-list'
                                            . ' comparison data' },
    ],
    doc => "intersect two variant lists (currently only SNPs are supported) and "
};

sub help_synopsis {
    my $self = shift;
    return <<EOS;
gt snp intersect list1.snps list2.snps 

gt snp intersect list1.snps list2.snps -i intersect.out -f1 f1.out -f2 f2.out

maq cns2view 1.cns | gt snp intersect mypositions  | less
EOS
}

sub help_detail{
    return <<EOS;
Intersect two SNP  and produce a report on the intersection.

The lists should be sorted by chromosome, then position.  Numeric chromosomes should come, first in numeric order, followed by alphabetic chromosomes in alpha order.  Positions should be in numeric order.

The counts of the above are displayed after execution.
You can re-create this output with a simple:
    wc -l intersection.out f1.only f2.only

By default the intersection file contains all data from file 1 at the intersected positions.  If the "detail" option is specified, the intersection file will contain data from both files, and an additional field which describes the genotype difference match/miss, and the transition from homozygous to heterozygous.

You can re-create the detail output with a shell command later w/o re-running:
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
    }
}

sub execute {
    my $self = shift;

    # setting a terrible example by using 2 and 3 letter variable names...   
    
    my $args = $self->bare_args;
    
    my $f1 = shift(@$args);
    unless (defined $f1) {
        $self->error_message("1 files, or 1 file plus STDIN, are required arguments!");
        $self->usage_message();
        return;
    }
    
    my $f2 = shift(@$args);
    unless (defined $f2) {
        # when only one file is specified, STDIN becomes the "1st" file
        $f2 = $f1;
        $f1 = '-';
    }

    if (@$args) {
        $self->error_message("extra args: @$args");
        return;
    }

    unless ($f1 eq '-' or -e $f1) {
        $self->error_message("File not found: $f1");
        return;
    }
    my $h1 = ($f1 eq '-' ? 'STDIN' : IO::File->new($f1));
    unless ($h1) {
        $self->error_message("Failed to open file $f1: $!");
        return;
    } 

    unless (-e $f2) {
        $self->error_message("File not found: $f2");
        return;
    }
    my $h2 = IO::File->new($f2);
    unless ($h2) {
        $self->error_message("Failed to open file $f2: $!");
        return;
    } 

    my $fi  = $self->intersect_output; 
    my $xi;
    if (my $fi = $self->intersect_output) {
        $xi = IO::File->new(">$fi") or die "Failed to open $fi: $!\n";
    }
    else {
        $xi = 'STDOUT';
    }

    my ($x1,$x2);
    my $f1o = $self->f1_only_output;
    if ($f1o) {
        $x1 = IO::File->new(">$f1o");
        unless ($x1) {
            $self->error_message("Failed to open file $x1: $!");
            return;
        } 
    }

    my $f2o = $self->f2_only_output; 
    if ($f2o) {
        $x2 = IO::File->new(">$f2o");
        unless ($x2) {
            $self->error_message("Failed to open file $x2: $!");
            return;
        } 
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

    my $format = ($self->detail ? 'compare' : 'default');
    my $printer = sub {
        no warnings;
        my ($h,$c1,$p1,$r1,$g1,$t1,$r2,$g2,$t2)=@_;
        my $g1_het = ($g1 eq $iub{$g1} ? 'hom' : 'het');
        if ($g2) {
            my $g2_het = ($g2 eq $iub{$g2} ? 'hom' : 'het');
            my $m = $iub_overlap{$g1}{$g2};
            unless (defined $m) {
                die "no value for >$g1< >$g2<\n";
            }
            my $desc = ($g1 eq $g2 ? 'match' : 'miss').'-'.$g1_het.'-'.$g2_het.'-'.$m.'-base-overlap';
            $intersect_groups{$desc}++; 
            if ($format eq 'compare') {
                $h->print(join("\t",$c1,$p1,$r1,$g1,$g2,$desc,@$t1,":",@$t2),"\n");
            }
            else {
                $h->print(join("\t",$c1,$p1,$r1,$g1,@$t1),"\n");
            }
        }
        else {
            if ($format eq 'compare') {
                $h->print(join("\t",$c1,$p1,$r1,$g1,$g1_het,@$t1,),"\n");
            } 
            else {
                $h->print(join("\t",$c1,$p1,$r1,$g1,@$t1),"\n");
            }
        }
    };

    getf1();
    getf2();
    while ($v1 or $v2) {
        my $cc = chr_cmp($c1,$c2);
        if (($cc == -1) or ($cc == 0 and $p1 < $p2)) {
            $n1++;
            $printer->($x1,$c1,$p1,$r1,$g1,\@t1) if $x1;
            getf1();
        }
        elsif ($cc == 1 or ($cc == 0 and $p2 < $p1)) {
            $n2++;
            $printer->($x2,$c2,$p2,$r2,$g2,\@t2) if $x2;
            getf2();
        }
        elsif ($cc == 0 and $p1 == $p2) {
            $ni++;
            $printer->($xi,$c1,$p1,$r1,$g1,\@t1,$r2,$g2,\@t2);
            getf1();
            getf2();
        }
        else {
            die "$v1\n$v2\n";
        }
    }
    print STDERR "$f1 only:\t$n1\n";
    print STDERR "$f2 only:\t$n2\n";
    print STDERR "intersection:\t$ni\n";
    for my $g (sort keys %intersect_groups) {
        print STDERR "\t", $g, ": ", $intersect_groups{$g}, "\n";
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

