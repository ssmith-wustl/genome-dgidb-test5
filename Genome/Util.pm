
package Genome::Util;

use strict;
use warnings;

our %iub2bases = (
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

our %bases2iub = reverse %iub2bases;

our %diploid_iub;
for my $key (keys %bases2iub) {
    if (length($key) > 2) {
        next;
    }
    elsif (length($key) == 2) {
        my @parts = split(//,$key);
        $diploid_iub{$parts[0]}{$parts[1]} = $bases2iub{$key};
        $diploid_iub{$parts[1]}{$parts[0]} = $bases2iub{$key};
    }
    else {
        $diploid_iub{$key}{$key} = $bases2iub{$key};
    }
}

our %iub_overlap;
for my $c1 (sort keys %iub2bases) {
    for my $c2 (sort keys %iub2bases) {
        my $n1 = $iub2bases{$c1};
        my $n2 = $iub2bases{$c2};
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

sub chromosome_cmp {
    our ($a,$b) = @_ if @_;
    no warnings;
    my $na = $a;
    my $nb = $b;
    ($a) = ($na =~ /.*(\d+|X|Y).*/);
    ($b) = ($nb =~ /.*(\d+|X|Y).*/);
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

