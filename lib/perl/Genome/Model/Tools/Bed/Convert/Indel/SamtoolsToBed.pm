package Genome::Model::Tools::Bed::Convert::Indel::SamtoolsToBed;

use strict;
use warnings;

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
    
    while(my $line = <$input_fh>) {
        my ($chromosome, $position, $star,
            $_calls, $consensus_quality, $_ref_quality, $_mapping_quality, $read_depth,
            $indel_call_1, $indel_call_2, @extra) = split("\t", $line);
        
        next unless $star eq '*'; #samtools indel format includes reference lines as well

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
        
            $self->write_bed_line($chromosome, $start, $stop, $reference, $variant, $consensus_quality, $read_depth);
        }
    }
    
    return 1;
}

1;
