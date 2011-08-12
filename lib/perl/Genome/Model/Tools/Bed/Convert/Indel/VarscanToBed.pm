package Genome::Model::Tools::Bed::Convert::Indel::VarscanToBed;
# DO NOT EDIT THIS FILE UNINTENTIONALLY IT IS A COPY OF VarscanToBed

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Bed::Convert::Indel::VarscanToBed {
    is => ['Genome::Model::Tools::Bed::Convert::Indel'],
};

sub help_brief {
    "Tools to convert var-scan indel format to BED.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
  gmt bed convert indel var-scan-to-bed --source indels_all_sequences --output indels_all_sequences.bed
EOS
}

sub help_detail {                           
    return <<EOS
    This is a small tool to take indel calls in var-scan format and convert them to a common BED format (using the first four columns).
EOS
}

sub process_source {
    my $self = shift;
    
    my $input_fh = $self->_input_fh;
    
    while(my $line = <$input_fh>) {
        my ($chromosome, $position, $_reference, $consensus, @extra) = split("\t", $line);
        my $quality = $extra[5];
        
        no warnings qw(numeric);
        next unless $position eq int($position); #Skip header line(s)
        use warnings qw(numeric);
        
        my ($indel_call_1, $indel_call_2) = split('/', $consensus);
        if(defined($indel_call_2)){
            if($indel_call_1 eq $indel_call_2) {
                undef $indel_call_2;
            }
        }
        for my $indel ($indel_call_1, $indel_call_2) {
            next unless defined $indel;
            next if $indel eq '*'; #Indicates only one indel call...and this isn't it!
            
            #position => 1-based position of the start of the indel
            #BED uses 0-based position of and after the event
        
            my ($reference, $variant, $start, $stop);
            
            #samtools pileup reports the position before the first deleted base or the inserted base ... so the start position is already correct for bed format
            $start = $position;
            if(substr($indel,0,1) eq '+') {
                $reference = '*';
                $variant = substr($indel,1);
                $stop = $start; #Two positions are included-- but an insertion has no "length" so stop and start are the same
            } elsif(substr($indel,0,1) eq '-') {
                $reference = substr($indel,1);
                $variant = '*';
                $stop = $start + length($reference);
            } else {
                $self->warning_message("Unexpected indel format encountered ($indel) on line:\n$line");
                #return;
                next;
            }
        
            # we take depth to mean total depth. varscan reports this in 2 fields, depth of reads
            # supporting the reference, and depth of reads supporting the called variant, so
            # we output the sum.
            my $depth = $extra[0] + $extra[1];
            $self->write_bed_line($chromosome, $start, $stop, $reference, $variant, $quality, $depth);
        }
    }
    
    return 1;
}

1;
