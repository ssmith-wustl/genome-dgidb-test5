package Genome::Model::Tools::Bed::Convert::Indel::SamtoolsToBed;

use strict;
use warnings;
use Data::Dumper;
use Genome;

class Genome::Model::Tools::Bed::Convert::Indel::SamtoolsToBed {
    is => ['Genome::Model::Tools::Bed::Convert::Indel'],
};

sub help_brief {
    "Tools to convert samtools indel format to BED.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
  gmt bed convert indel samtools-to-bed --source indels_all_sequences --output indels_all_sequences.bed
EOS
}

sub help_detail {
    return <<EOS
    This is a small tool to take indel calls in samtools format and convert them to a common BED format (using the first four columns).
EOS
}

sub process_source {
    my $self = shift;

    my $input_fh = $self->_input_fh;

    while(my $line = <$input_fh>){
        my ($chromosome, $position, $star,$_calls, $consensus_quality, $_ref_quality, $_mapping_quality, $read_depth, $indel_call_1, $indel_call_2); #pileup variables
        my ($id, $reference_bases, $variant_bases, @extra); #mpileup variables that aren't included in pileup variables.

        my @line_array = split("\t", $line);
        if ($line_array[2] eq '.') { #deciding if it's pileup or mpileup

            #seven is how many columns in the vcf file for mpileup
            ($chromosome, $position, $id, $reference_bases, $variant_bases, $consensus_quality, @extra) = split("\t", $line);

            $consensus_quality = sprintf("%2.f", $consensus_quality); #Rounds quality because mpileup doesn't automatically do that.
            $indel_call_1 =  $self->reduce_strings($reference_bases, $variant_bases);
            $indel_call_2='*';
            $extra[1] =~ /DP=(\d+)/;
            $read_depth = $1;
        }else {

            #pileup output file that has ten columns in the vcf file 
            ($chromosome, $position, $star, $_calls, $consensus_quality, $_ref_quality, $_mapping_quality, $read_depth, $indel_call_1, $indel_call_2, 
            ) = split("\t", $line);
            next unless $star eq '*'; #samtools indel format includes reference lines as wel
        }

        for my $indel ($indel_call_1, $indel_call_2) {
            next if $indel eq '*'; #Indicates only one indel call...and this isn't it!
            my ($reference, $variant, $start, $stop);

            $start = $position - 1; #Convert to 0-based coordinate
            if(substr($indel,0,1) eq '+') {
                $reference = '*';
                $variant = substr($indel,1);
                $stop = $start; #Two positions are included-- but an insertion has no "length" so stop and start are the same
            } elsif(substr($indel,0,1) eq '-') {
                $start += 1; #samtools reports the position before the first deleted base
                $reference = substr($indel,1); 
                $variant = '*';
                $stop = $start + length($reference);
            } else {
                $self->warning_message("Unexpected indel format encountered ($indel) on line:\n$line");
                #return; skip wrong indel format line instead of failing for now
                next;
            }

            $self->write_bed_line($chromosome, $start, $stop, $reference, $variant, $consensus_quality, $read_depth); #took out position between stop and reference 
        }
    }
    return 1;
}


#mpileup subroutine created so we replicate the identical output for the bam file
sub reduce_strings {
    my $self = shift;
    my ($reference, $indel)= @_;
    my $refindex = length($reference);
    my $indindex = length($indel);
    my @ref = split(//, $reference);
    my @indel = split(//, $indel);
    my @difference;
    my $sign;
    if ($refindex >  $indindex) {
        $sign = '-';

    } elsif ($refindex < $indindex) {
        $sign='+' ;

    } else {
        return '';
    }
    my ($r,$i);
    for($r = ($refindex - 1), $i = ($indindex -1); $r >= 0 and $i >= 0; $r--, $i--) {
        if ($ref[$r]eq $indel[$i]) {
            next;
        } else {
            while (!($ref[$r] eq  $indel[$i]) and $r>=0 and $i >=0) {
                if($sign eq '-') {
                    unshift @difference, $ref[$r];
                    $r--;
                } else {
                    unshift @difference, $indel[$i];
                    $i--;
                }
            }

        }
    }

    if ($sign eq '-'){
        while ($r>=0){
            unshift @difference, $ref[$r];
            $r--;
        }
    } else{
        while ($i>=0){
            unshift @difference, $indel[$i];
            $i--;
        }
    }
    my $result= join('',($sign,@difference));
    return $result ;
}

1;
