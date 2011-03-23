package Genome::Model::Tools::Nimblegen::DesignFromSv;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Sort::Naturally qw( nsort );
use Genome::Sys;

class Genome::Model::Tools::Nimblegen::DesignFromSv {
    is => 'Command',
    has => [
    sv_file => {
        type => 'String',
        is_optional => 0,
        doc => "A HQfiltered formatted file of SV sites to generate probe regions for. Assumes STDIN if not specified",
    },
    output_file => {
        type => 'String',
        is_optional => 1,
        doc => "Output file. Assumes STDOUT if not specified",
    },
    assembly_format => {
        type => 'Boolean',
        is_optional => 1,
        default => 0,
        doc => "input file is assembly format",
    },
    span => {
        type => 'Integer',
        is_optional => 1,
        default => 200,
        doc => "The region to be spanned",
    },
    exclude_non_canonical_sites => {
        type => 'Boolean',
        is_optional => 1,
        default => 1,
        doc => "whether or not to remove sites on the mitochondria or non-chromosomal contigs",
    },
    include_y => {
        type => 'Boolean',
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
    resolution => {
        type => 'Integer',
        is_optional => 1,
        default => 10000,
        doc => "Filter out the resolution > this number and not output it to nimblegen list."
    },
    count_file => {
        type => 'String',
        is_optional => 1,
        doc => "Count the whole bases to be covered."
    },
    filtered_out_file => {
        type => 'String',
        is_optional => 1,
        doc => "Save those in .capture but not in .nimblegen. Writes to STDERR if undefined"
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
        $output_fh = IO::File->new($self->output_file,"w+");
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

    my $count_fh;
    if(defined $self->count_file) {
        $count_fh = IO::File->new($self->count_file,"a+");
        unless($count_fh) {
            $self->error_message("Unable to open file " . $self->count_file . " for writing.");
            return;
        }
    }
    else {
        $count_fh = IO::File->new_from_fd(fileno(STDOUT), "w");
        unless($count_fh){
            $self->error_message("Unable to open STDOUT for writing.");
            return;
        }
    }

    my $filtered_out_fh;
    if(defined $self->filtered_out_file) {
        $filtered_out_fh = IO::File->new($self->filtered_out_file,"w");
        unless($filtered_out_fh) {
            $self->error_message("Unable to open file ". $self->filtered_out_file . " for writing.");
            return;
        }
    }
    else {
        $filtered_out_fh = IO::File->new_from_fd(fileno(STDERR), "w");
        unless($filtered_out_fh){
            $self->error_message("Unable to open STDERR for writing.");
            return;
        }
    }

    my $input_fh;
    if(defined $self->sv_file) {
        $input_fh = IO::File->new($self->sv_file,"r");
        unless($input_fh) {
            $self->error_message("Unable to open file ". $self->sv_file . " for reading.");
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
    my %cover = ();
    while(my $line = $input_fh->getline) {
        next if $line =~ /^#/;  #skip comments
        chomp $line;

        if($self->assembly_format) {
            my @list = split(/\t/,$line);
            my @sub_list = @list[1 .. 6];
            my $new_col = join(".",@sub_list);
            $line = "$new_col\t".$line;
        }



        #my ($id,$chr1,$outer_start,$inner_start,$chr2,$inner_end,$outer_end,$type,$orient, $minsize) = split /\s+/, $line;
        my ($id, )=split("\t", $line);
        my ($chr1,$outer_start,$inner_start,$chr2,$inner_end,$outer_end) = ($id =~ /(\S+)\.(-*\d+)\.(-*\d+)\.(\S+)\.(-*\d+)\.(-*\d+)/);
        if(!defined $chr1 || !defined $chr2) {
            print "$line\n";
        }
        if($self->exclude_non_canonical_sites && ($chr1 =~ /^[MN]T/ || $chr2 =~ /^[MN]T/)) {
            printf $filtered_out_fh "Non-canonical: %s\n", $line;
            next;
        }
        if(!$self->include_y && ($chr1 =~ /^Y/ || $chr2 =~ /^Y/)) {
            printf $filtered_out_fh "Exclude chrY: %s\n", $line;
            next;
        }

        my $outer_start_ = $outer_start - $self->span;
        my $inner_start_ = $inner_start + $self->span;
        my $inner_end_ = $inner_end - $self->span;
        my $outer_end_ = $outer_end + $self->span;

        if($outer_start - $self->span < 1) {
            $outer_start_ = 1;
        }
        if($outer_start - $self->span > $chromosome_lengths{$chr1}) {
            printf $filtered_out_fh "Out of bounds: %s\n", $line;
            next;
        }
        if($inner_start + $self->span < 1) {
            $inner_start_ = 1;
        }
        if($inner_start + $self->span > $chromosome_lengths{$chr1}) {
            $inner_start_ = $chromosome_lengths{$chr1};
        }
        if($outer_end + $self->span < 1){
            printf $filtered_out_fh "Out of bounds: %s\n", $line;
            next;
        }
        if($outer_end + $self->span > $chromosome_lengths{$chr2}) {
            $outer_end_ = $chromosome_lengths{$chr2};
        }
        if($inner_end - $self->span < 1){
            $inner_end_ = 1;
        }
        if($inner_end - $self->span > $chromosome_lengths{$chr2}) {
            $inner_end_ = $chromosome_lengths{$chr2};
        }

        # filter out those resolution > 2k
        if($inner_start_ - $outer_start_ > $self->resolution || $outer_end_ - $inner_end_ > $self->resolution) {
            printf $filtered_out_fh "Resolution too high: %s\n", $line;
            next;
        }

        # record how many base pair has been covered
        for(my $i = $outer_start_; $i <= $inner_start_; $i++) {
            ${$cover{$chr1}}{$i} = 1 if(! defined $cover{$chr1}{$i});
        }
        for(my $i = $inner_end_; $i <= $outer_end_; $i++) {
            ${$cover{$chr1}}{$i} = 1 if(! defined $cover{$chr1}{$i});
        }

        #if($type !~ /INS/) {#|| ($type =~ /DEL/ && $minsize > 1000)) {
        printf $output_fh "chr%s\t%d\t%d\t%d\t%s\n",$chr1,$outer_start_, $inner_start_, (($inner_start_) - ($outer_start_)), $line;
        printf $output_fh "chr%s\t%d\t%d\t%d\t%s\n",$chr2,$inner_end_, $outer_end_, (($outer_end_) - ($inner_end_)), $line;
        #}
        #else {
        #    printf $output_fh "chr%s\t%d\t%d\t%d\t%s\n",$chr1,$outer_start - 100, $outer_end + 100, (($outer_end + 100) - ($outer_start - 100)), $line;
        #}
    }

    my $inall = 0;
    my $chr;
    my $base;
    foreach $chr (keys %cover) {
        foreach $base (keys %{$cover{$chr}}) {
            $inall++;
        }
    }
    printf $count_fh "%s\t%d bps covered\n", $self->output_file, $inall;

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
