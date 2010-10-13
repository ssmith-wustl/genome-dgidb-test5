package Genome::Model::Tools::Nimblegen::DesignFromAnnotation;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Sort::Naturally qw( nsort );
use Genome::Utility::FileSystem;

class Genome::Model::Tools::Nimblegen::DesignFromAnnotation {
    is => 'Command',
    has => [
    annotation_file => { 
        type => 'String',
        is_optional => 1,
        doc => "An annotation file of sites to generate probe regions for. Assumes STDIN if not specified",
    },
    output_file => {
        type => 'String',
        is_optional => 1,
        doc => "Output file. Assumes STDOUT if not specified",
    },
    span => {
    	type => 'Integer',
    	is_optional => 1,
    	default => 100,
    	doc => "The region to be spanned",
    },
    exclude_non_canonical_sites => {
        type => 'Bool',
        is_optional => 1,
        default => 1,
        doc => "whether or not to remove sites on the mitochondria or non-chromosomal contigs",
    },
    include_y => {
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

    my $span = $self->span;  #

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
        if($self->exclude_non_canonical_sites && $line =~ /^[MN]T/) {
            next;
        }
        if(!$self->include_y && $line =~ /^Y/) {
            next;
        }
        chomp $line;
        next if($line =~ /^chromosome_name/ || $line =~ /^Chr/);
        my ($chr,$start,$stop,) = split /\t/, $line;
        if($start - $span < 1 || $start - $span > $chromosome_lengths{$chr} - 1) {
            $self->error_message("Start coordinate out of bounds. Skipping $line");
	    print STDOUT "$line\n";
            next;
        }
        if($stop + $span < 1 || $stop + $span > $chromosome_lengths{$chr} - 1) {
            $self->error_message("Stop coordinate out of bounds. Skipping $line");
	    print STDOUT "$line\n";
            next;
        }
        printf $output_fh "chr%s\t%d\t%d\t%d\t%s\n",$chr,$start - $span, $stop + $span, (($stop + $span) - ($start - $span)), $line;
    }

    
    return 1;

}

sub help_brief {
    "Takes a file in annotation format and produces a list of regions to target for validation.";
}

sub help_detail {                           
    return <<EOS 
   Takes a file in annotation format and produces a list of regions to target for validation via Nimblegen Solid Phase Capture Array. 
EOS
}

1;

