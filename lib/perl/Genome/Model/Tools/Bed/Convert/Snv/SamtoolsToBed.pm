package Genome::Model::Tools::Bed::Convert::Snv::SamtoolsToBed;

use strict;
use warnings;
use Data::Dumper;
use Genome;

class Genome::Model::Tools::Bed::Convert::Snv::SamtoolsToBed {
    is => ['Genome::Model::Tools::Bed::Convert::Snv'],
};

sub help_brief {
    "Tools to convert samtools SNV format to BED.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
  gmt bed convert snv samtools-to-bed --source snps_all_sequences --output snps_all_sequences.bed
EOS
}

sub help_detail {
    return <<EOS
    This is a small tool to take SNV calls in samtools format and convert them to a common BED format (using the first five columns).
EOS
}

sub process_source {
    my $self = shift;

    my $input_fh = $self->_input_fh;

    while(my $line = <$input_fh>) {
        my @mpileup = split("\t", $line);
        my ($chromosome, $position, $id, $reference, $consensus, $quality, $depth, $map_qual, @extra);

        if($mpileup[2] eq '.') {
            ($chromosome, $position, $id,$reference, $consensus , $quality, @extra) = split("\t", $line) ;
            $quality = sprintf("%2.f", $quality);
            if($extra[1] =~ /DP=(\d+)/) {
                $depth = $1;
            } else { 
                $self->warning_message("read depth not found on line $line");
            }
            if ($extra[1] =~ /MQ=(\d+)/) {
                $map_qual = $1;
            } else {
                $self->warning_message("mapping quality cannot be found on line $line");
            }
        } else {
            ($chromosome, $position, $reference, $consensus, $quality, $map_qual, @extra)=split("\t", $line) ;
            $depth = $extra[1];
        }
        #position => 1-based position of the SNV
        #BED uses 0-based position of and after the event
        $self->write_bed_line($chromosome, ($position - 1), $position, $reference, $consensus, $quality, $depth);
    }
    return 1;
}

sub convert_bed_to_detector {
    my $self = shift;
    my $detector_file = $self->detector_style_input;
    my $bed_file = $self->source;
    my $output = $self->output;

    my $ofh = Genome::Sys->open_file_for_writing($output);
    my $detector_fh = Genome::Sys->open_file_for_reading($detector_file);
    my $bed_fh = Genome::Sys->open_file_for_reading($bed_file);
    OUTER: while(my $line = $bed_fh->getline){
        chomp $line;
        my ($chr,$start,$stop,$refvar,@data) = split "\t", $line;
        my ($ref,$var) = split "/", $refvar;
        my $scan=undef;
        while(my $dline = $detector_fh->getline){
            chomp $dline;
            my ($dchr,$dpos,$dref,$dvar) = split "\t", $dline;
            if(($chr eq $dchr)&&($stop == $dpos)&&($ref eq $dref)&&($var eq $dvar)){
                print $ofh $dline."\n";
                next OUTER;
            }
        }
    }
    $bed_fh->close;
    $ofh->close;
    $detector_fh->close;
    return 1;
}

1;
