package Genome::Model::Tools::Nimblegen::DesignFromSv;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Sort::Naturally qw( nsort );
use Genome::Utility::FileSystem;

class Genome::Model::Tools::Nimblegen::DesignFromSv {
    is => 'Command',
    has => [
    sv_file => { 
        type => 'String',
        is_optional => 1,
        doc => "A HQfiltered formatted file of SV sites to generate probe regions for. Assumes STDIN if not specified",
    },
    output_file => {
        type => 'String',
        is_optional => 1,
        doc => "Output file. Assumes STDOUT if not specified",
    },
    exclude_non_canonical_sites => {
        type => 'Bool',
        is_optional => 1,
        default => 1,
        doc => "whether or not to remove sites on the mitochondria or non-chromosomal contigs",
    },
    inlcude_y => {
        type => 'Bool',
        is_optional => 1,
        default => 1,
        doc => "whether or not to include sites on the Y chromosome in the output",
    },
    reference_index => {
        type => 'String',
        is_optional => 0,
        doc => "samtools index of the reference sequence",
        default => "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa.fai",
    },
    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;

    my $reference_index = $self->reference_index;

    my $fh = IO::File->new($reference_index,"r"); 
    unless($fh) {
        $self->error_message("Unable to open the reference sequence index: $reference_index");
        return;
    }
    
    #read in the index to get the chromosome lengths
    my %chromosome_lengths;
    while(my $line = $fh->getline) {
        chomp $line;
        my ($chr, $length) = split /\t/, $line;
        $chromosome_lengths{$chr} = $length;
    }
    $fh->close;

    my $output_fh;
    if(defined $self->output_file) {
        $output_fh = IO::File->new($self->output_file,"w");
        unless($output_fh) {
            $self->error_message("Unable to open file " . $self->output_file . " for writing.");
            return;
        }
    }
    else {
        $output_fh = IO::File->new_from_fd(fileno(STDOUT),"w");
        unless($output_fh) {
            $self->error_message("Unable to open STDOUT for writing.");
            return;
        }
    }

    my $input_fh;
    if(defined $self->annotation_file) {
        $input_fh = IO::File->new($self->annotation_file,"r");
        unless($input_fh) {
            $self->error_message("Unable to open file ". $self->annotation_file . " for reading.");
            return;
        }
    }
    else {
        $input_fh = IO::File->new_from_fd(fileno(STDIN),"r");
        unless($input_fh) {
            $self->error_message("Unable to open STDIN for reading.");
            return;
        }
    }
    
    while(my $line = $input_fh->getline) {
        next if $line =~ /^#/;  #skip comments
        chomp $line;
        my ($id,$chr1,$outer_start,$inner_start,$chr2,$inner_end,$outer_end,$type,$orient, $minsize) = split /\s+/, $line;
        if($self->exclude_non_canonical_sites && ($chr1 =~ /^[MN]T/ || $chr2 =~ /^[MN]T/)) {
            next;
        }
        if(!$self->inlcude_y && ($chr1 =~ /^Y/ || $chr2 =~ /^Y/)) {
            next;
        }
        if($outer_start - 100 < 1 || $outer_start - 100 > $chromosome_lengths{$chr1} - 1) {
            $self->error_message("Outer Start coordinate out of bounds: $line");
            return;
        }
        if($inner_start + 100 < 1 || $inner_start + 100 > $chromosome_lengths{$chr1} - 1) {
            $self->error_message("Inner Start coordinate out of bounds: $line");
            return;
        }


        if($inner_end - 100 < 1 || $inner_end - 100 > $chromosome_lengths{$chr2} - 1) {
            $self->error_message("Inner end coordinate out of bounds: $line");
            return;
        }
        if($outer_end + 100 < 1 || $outer_end + 100 > $chromosome_lengths{$chr2} - 1) {
            $self->error_message("Stop coordinate out of bounds: $line");
            return;
        }

        if($type !~ /INS/) {#|| ($type =~ /DEL/ && $minsize > 1000)) {
            printf $output_fh "chr%s\t%d\t%d\t%d\t%s\n",$chr1,$outer_start - 100, $inner_start + 100, (($inner_start + 100) - ($outer_start - 100)), $line;
            printf $output_fh "chr%s\t%d\t%d\t%d\t%s\n",$chr2,$inner_end - 100, $outer_end + 100, (($outer_end + 100) - ($inner_end - 100)), $line;
        }
        else {
            printf $output_fh "chr%s\t%d\t%d\t%d\t%s\n",$chr1,$outer_start - 100, $outer_end + 100, (($outer_end + 100) - ($outer_start - 100)), $line;
        }
    }

    
    return 1;

}

sub help_brief {
    "Takes an Sv file and produces a list of regions to target for validation.";
}

sub help_detail {                           
    return <<EOS 
   Takes an SV file and produces a list of regions to target for validation via Nimblegen Solid Phase Capture Array. 
EOS
}

1;

