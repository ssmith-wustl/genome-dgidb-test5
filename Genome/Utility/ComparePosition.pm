package Genome::Utility::ComparePosition;

use strict;
use warnings;
use above 'Genome';
use Exporter;

our(@ISA, @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(compare_position compare_chromosome);


sub compare_position{
    my ($chr1, $pos1, $chr2, $pos2) = @_;
    unless (defined $chr1 and defined $chr2 and defined $pos1 and defined $pos2){
        return undef;
    }
    my $chr_cmp = compare_chromosome($chr1,$chr2);
    if ($chr_cmp < 0){
        return -1;
    }elsif ($chr_cmp == 0){
        return $pos1 <=> $pos2;
    }else{
        return 1;
    }
}

sub compare_chromosome{
    my ($chr1, $chr2) = @_;
    unless (defined $chr1 and defined $chr2){
        return undef;
    }
    if ($chr1 =~ /^[xyXY]$/ ){
        if ($chr2 =~ /^[xyXY]$/ ){
            return uc $chr1 cmp uc $chr2;
        }else{
            return 1; #chr1 = XY > any digit chrom
        }
    }elsif($chr2 =~ /^[xyXY]$/ ){
        return -1; #chr1 = digit < any XY
    }else{
        return $chr1 <=> $chr2;
    }
}

=pod

SYNOPSIS:

use Genome::Utility::ComparePosition qw/compare_position compare_chromosome/;
provides two methods 
compare_position($chr1, $pos1, $chr2, $pos2)
compare_chromosome($chr1, $chr2)
that return -1, 0, or 1 ala the cmp or <=> operators

=cut
1;

