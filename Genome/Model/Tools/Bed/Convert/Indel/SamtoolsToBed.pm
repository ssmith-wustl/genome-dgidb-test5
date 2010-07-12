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
    
    for my $line (<$input_fh>) {
        my ($chromosome, $position, $star,
            $_calls, $_consensus_quality, $_ref_quality, $_mapping_quality, $_read_depth,
            $indel_call_1, $indel_call_2, @extra) = split("\t", $line);
        
        next unless $star eq '*'; #samtools indel format includes reference lines as well

        for my $indel ($indel_call_1, $indel_call_2) {
            next if $indel eq '*'; #Indicates only one indel call...and this isn't it!
            
            #position => 1-based position of the start of the indel
            #BED uses 0-based position of and after the event
            
            my ($reference, $variant, $start, $stop);
            
            $start = $position; #samtools reports position before indel so +1 then -1 to switch to 0-based.            
            if(substr($indel,0,1) eq '+') {
                $reference = '*';
                $variant = substr($indel,1);
                $stop = $start + 2; #Two positions are included--the base preceding and the base following the insertion event
            } elsif(substr($indel,0,1) eq '-') {
                $reference = substr($indel,1);
                $variant = '*';
                $stop = $start + length($reference);
            } else {
                $self->error_message('Unexpected indel format encountered: ' . $indel);
                return;
            }
        
            $self->write_bed_line($chromosome, $start, $stop, $reference, $variant);
        }
    }
    
    return 1;
}

1;
