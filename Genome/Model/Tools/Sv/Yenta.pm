package Genome::Model::Tools::Sv::Yenta;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Sv::Yenta {
    is => 'Command',
    has => [
    breakdancer_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "Input file of breakdancer output for a single individual",
    },
    output_dir =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Output directory name for placement of directories",
    },        
    tumor_bam =>
    {
        type => 'String',
        is_optional => 0,
        doc => "bam file location for tumor",
    },
    normal_bam =>
    {
        type => 'String',
        is_optional => 0,
        doc => "bam file location for normal",
    },
    types => {
        type => 'String',
        is_optional => 1,
        doc => "Comma separated string of types to graph",
        default => "INV,INS,DEL,ITX,CTX",
    },
    possible_BD_type => {
        type => 'hashref',
        doc => "hashref of possible BreakDancer SV types",
        is_optional => 1,
        default => {INV => 1,INS => 1,DEL => 1,ITX => 1,CTX => 1,},
    },
    yenta_program => {
        type => "String",
        default => "/gscuser/dlarson/yenta/trunk/yenta",
        doc => "executable of yenta to use", 
        is_optional => 1,
    },
    exon_bam => {
        type => "String",
        default => "/gscmnt/sata831/info/medseq/dlarson/annotation_sam_files/new_annotation_sorted.bam",
        doc => "bam file of exons to use for displaying gene models", 
        is_optional => 1,
    },
    buffer_size => {
        type => "Integer",
        default => 500,
        doc => "number of bases to include on either side of the predicted breakpoint(s)",
        is_optional => 1,
    },
    yenta_options => {
        type => "String",
        default => "",
        doc => "option string to pass through to yenta for experimental options etc",
        is_optional => 1,
    },

    ],
};


sub execute {
    my $self=shift;
    $DB::single = 1; 

    #test architecture to make sure we can run yenta program
    #copied from G::M::T::Maq""Align.t 
    unless (`uname -a` =~ /x86_64/) {
        $self->error_message(`uname -a`); #FIXME remove
        $self->error_message("Must run on a 64 bit machine");
        die;
    }
    #Not allowed to store hash in UR?

    my @types = map { uc $_ } split /,/, $self->types;
    my $allowed_types = $self->possible_BD_type;
    foreach my $type (@types) {
        unless(exists($allowed_types->{$type})) {
            $self->error_message("$type type is not a valid BreakDancer SV type");
            return;
        }
    }
    my %types = map {$_ => 1} @types; #create types hash


    unless(-f $self->breakdancer_file) {
        $self->error_message("breakdancer file is not a file: " . $self->breakdancer_file);
        return;
    }

    my $indel_fh = IO::File->new($self->breakdancer_file);
    unless($indel_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->breakdancer_file );
        return;
    }

    #TODO These should all get checked somehow
    my $tumor_bam = $self->tumor_bam;
    unless(-e $tumor_bam) {
        $self->error_message("$tumor_bam does not exist");
        return;
    }

    my $normal_bam = $self->normal_bam;
    unless(-e $normal_bam) {
        $self->error_message("$normal_bam does not exist");
        return;
    }

    my $output_dir = $self->output_dir;
    unless(-d $output_dir) {
        $self->error_message("$output_dir does not exist");
        return;
    }

    my $grapher = $self->yenta_program;
    unless(-e $grapher && -x $grapher) {
        $self->error_message("$grapher does not exists or is not an executable");
        return;
    }

    my $additional_opts = $self->yenta_options;
    my $exon_file = $self->exon_bam;
    if($exon_file) {
        unless(-e $exon_file) {
            $self->error_message("$exon_file does not exist");
            return;
        }
        $additional_opts = $additional_opts ? $additional_opts . " -g $exon_file" : "-g $exon_file";
    }
    $self->status_message("Using option string $additional_opts");
    my $buffer = $self->buffer_size;

    my $count = 0;
    #assuming we are reasonably sorted
    while ( my $line = $indel_fh->getline) {
        chomp $line;
        $line =~ s/"//g; #kill any quotes that may have snuck in
        my ($chr1,
            $chr1_pos,
            $orientation1,
            $chr2,
            $chr2_pos,
            $orientation2,
            $type,
            $size,
        ) = split /\s+/, $line; 
        #skip headers
        next if $line =~ /START|TYPE/;
        #validate columns
        unless($chr1 =~ /^[0-9XYNMT_]+$/i) {
            $self->error_message("First column contains invalid chromosome name $chr1 at line " . $indel_fh->input_line_number);
            $self->error_message("Please confirm your file is formatted as follows: chr1	pos1	dummy	chr2	pos2	dummy	type");
            return;
        }
        unless($chr2 =~ /^[0-9XYNMT_]+$/i) {
            $self->error_message("Fourth column contains invalid chromosome name $chr2 at line " . $indel_fh->input_line_number);
            $self->error_message("Please confirm your file is formatted as follows: chr1	pos1	dummy	chr2	pos2	dummy	type");
            return;
        }
        unless($chr1_pos =~ /^\d+$/) {
            $self->error_message("Second column contains non-digit characters $chr1_pos at line " . $indel_fh->input_line_number);
            $self->error_message("Please confirm your file is formatted as follows: chr1	pos1	dummy	chr2	pos2	dummy	type");
            return;
        }
        unless($chr2_pos =~ /^\d+$/) {
            $self->error_message("Fifth column contains non-digit characters $chr2_pos at line " . $indel_fh->input_line_number);
            $self->error_message("Please confirm your file is formatted as follows: chr1	pos1	dummy	chr2	pos2	dummy	type");
            return;
        }
        if(exists($types{$type})) {
            $count++;
            #then we should graph it
            #Doing this based on chromosomes in case types ever change
            if($chr1 eq $chr2) {
                my $name = "$output_dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_Tumor_${type}.q1.png";
                my $cmd = "$grapher -q 1 -b $buffer -o $name $additional_opts $tumor_bam $chr1 $chr1_pos $chr2_pos";
                $self->error_message("Running: $cmd");
                system($cmd);
                $name = "$output_dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_Normal_${type}.q1.png";
                $cmd = "$grapher -q 1 -b $buffer  -o $name $additional_opts $normal_bam $chr1 $chr1_pos $chr2_pos";
                $self->error_message("Running: $cmd");
                system($cmd);
                $name = "$output_dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_Tumor_${type}.q0.png";
                $cmd = "$grapher -q 0 -b $buffer  -o $name $additional_opts $tumor_bam $chr1 $chr1_pos $chr2_pos";
                $self->error_message("Running: $cmd");
                system($cmd);
                $name = "$output_dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_Normal_${type}.q0.png";
                $cmd = "$grapher -q 0 -b $buffer  -o $name $additional_opts $normal_bam $chr1 $chr1_pos $chr2_pos";
                $self->error_message("Running: $cmd");
                system($cmd);
            }
            else {
                my $name = "$output_dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_Tumor_${type}.q1.png";
                my $cmd = "$grapher -q 1 -b $buffer -o $name $additional_opts $tumor_bam $chr1 $chr1_pos $chr1_pos $tumor_bam $chr2 $chr2_pos $chr2_pos";
                $self->error_message("Running: $cmd");
                system($cmd);
                $name = "$output_dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_Normal_${type}.q1.png";
                $cmd = "$grapher -q 1 -b $buffer  -o $name $additional_opts $normal_bam $chr1 $chr1_pos $chr1_pos $normal_bam $chr2 $chr2_pos $chr2_pos";
                $self->error_message("Running: $cmd");
                system($cmd);
                $name = "$output_dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_Tumor_${type}.q0.png";
                $cmd = "$grapher -q 0 -b $buffer  -o $name $additional_opts $tumor_bam $chr1 $chr1_pos $chr1_pos $tumor_bam $chr2 $chr2_pos $chr2_pos";
                $self->error_message("Running: $cmd");
                system($cmd);
                $name = "$output_dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_Normal_${type}.q0.png";
                $cmd = "$grapher -q 0 -b $buffer  -o $name $additional_opts $normal_bam $chr1 $chr1_pos $chr1_pos $normal_bam $chr2 $chr2_pos $chr2_pos";
                $self->error_message("Running: $cmd");
                system($cmd);
            }
        }
        unless(exists($allowed_types->{$type})) {
            $self->error_message("Type $type invalid");
            $self->error_message("Valid types are " . join("\t",keys %{$allowed_types}));
            $self->error_message("Please confirm your file is formatted as follows: chr1	pos1	dummy	chr2	pos2	dummy	type");
            return;
        }


    }

    $indel_fh->close; 

    return 1;
}

1;

sub help_detail {
    my $help = <<HELP;
Ken Chen's BreakDancer predicts large structural variations by examining read pairs. This module uses the yenta program to graph read pairs for a given set of regions. yenta operates by scanning a maq map file for reads in the regions and matches up pairs across those regions. The output consists of a set of tracks for each region. One track is the read depth across the region (excluding gapped reads) the other is a so called barcode output. For multiple regions, the regions are displayed in order listed in the filename. Read depth tracks first, then the barcode graphs. Reads are represented as lines and pairs are joined by arcs. These are color coded by abnormal read pair type as follows:

Mapping status                                      Color
Forward-Reverse, abnormal insert size               magenta
Forward-Forward                                     red
Reverse-Reverse                                     blue
Reverse-Forward                                     green
One read unmapped                                   yellow
One read mapped to a different chromosome           cyan

Yenta.pm generates 4 PNG images for each predicted SV, 2 for tumor and 2 for normal. There is a q0 file showing reads of all mapping qualities and a q1 file showing reads of mapping quality 1 or more. A maq mapping quality of zero indicates a repeat region that mapped multiple places in the genome equally well.

The naming convention of the files produced is as follows:
chr_pos_chr_pos_tumor/normal_type.q#.png

The input file must be formatted as follows:
chr1	position	dummy	chr2	position2	dummy	type

HELP

}

sub help_brief {
    return "This module takes a breakdancer file and uses the rudimentary graphical tool yenta to graph the read pairs.";
}


