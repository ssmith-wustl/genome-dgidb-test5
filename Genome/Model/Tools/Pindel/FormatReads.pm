package Genome::Model::Tools::Pindel::FormatReads;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Pindel::FormatReads {
    is => ['Command'],
    has => [
        sw_reads => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'File of smith waterman reads to be sorted, dumped from samtools view. ',
        },
        one_end_reads => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'File of single reads to be sorted, dumped from samtools view. Must be sorted such that their mate read is adjacent in the file (such as with gmt pindel sort-mate).',
        },
        output_file_sw => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The output file for smith waterman reads, formatted in the pindel input format',
        },
        output_file_one_end => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The output file for single end mapped reads, formatted in the pindel input format',
        },
        tag => {
            is => 'string',
            is_input => '1',
            doc => 'The tag to be associated with all of these reads. Useful for distinguishing samples. I.E. BRC1T, OV1M, etc',
        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
        _ms_cutoff => {
            is => 'Integer',
            default => 0,
            doc => '',
        },
    ],
};
        
sub help_brief {
    "Translates reads from samtools view format to pindel input format";
}

sub help_synopsis {
    return <<"EOS"
gmt pindel format-reads --sw-reads dumped_reads.sw --one-end-reads dumped_reads.oneend --output-file-sw formatted_sw.out --output-file-one-end formatted_one_end.out --tag BRC1
gmt pindel format-reads --sw dumped_reads.sw --one dumped_reads.oneend --output-file-sw formatted_sw.out --output-file-one formatted_one_end.out --tag BRC1
EOS
}

sub help_detail {                           
    return <<EOS 
Takes in reads dumped from a bam via samtools view and produces and output file formatted such that pindel can take it as input. Each read will be translated into three lines that pindel can read.
EOS
}

sub execute {
    my $self = shift;
    $DB::single = 1;

    # Skip if output files exist
    if (($self->skip_if_output_present)&&(-s $self->output_file_sw)&&(-s $self->output_file_one_end)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    my $sw_ifh = IO::File->new($self->sw_reads);
    unless($sw_ifh) {
        $self->error_message("Unable to open " . $self->sw_reads. " for reading. $!");
        die;
    }
    my $one_end_ifh = IO::File->new($self->one_end_reads);
    unless($one_end_ifh) {
        $self->error_message("Unable to open " . $self->one_end_reads. " for reading. $!");
        die;
    }

    my $sw_ofh = IO::File->new($self->output_file_sw, "w");
    unless($sw_ofh) {
        $self->error_message("Unable to open " . $self->output_file_sw . " for writing. $!");
        die;
    }
    my $one_end_ofh = IO::File->new($self->output_file_one_end, "w");
    unless($one_end_ofh) {
        $self->error_message("Unable to open " . $self->output_file_one_end . " for writing. $!");
        die;
    }

    #FIXME make one set or the other optional
    while (my $line = $sw_ifh->getline) {
        $self->parse_smith_waterman($line, $sw_ofh);
    }

    while (my $line = $one_end_ifh->getline) {
           my $line2 = $one_end_ifh->getline;
           $self->parse_one_end($line, $line2, $one_end_ofh);
    }

    $sw_ifh->close;
    $sw_ofh->close;
    $one_end_ifh->close;
    $one_end_ofh->close;

    return 1; 
}

sub parse_smith_waterman {
    my ($self, $line, $ofh) = @_; 
    my ($name, $flag, $chromosome, $position, $ms, $insert_size, $sequence) = split(/\s+/, $line);

    my ($mate_strand, $mate_position);
    if (($flag / 16) % 2 == 0) { #forwards (mate is reverse)
        $mate_strand = "-";
        $mate_position = $position + ($insert_size - length $sequence);
    } else { #reverse (mate is forwards)
        $mate_strand = "+";
        $sequence = $self->reverse_complement($sequence);
        $mate_position = $position - ($insert_size - 2 * length $sequence);
    }

    $ofh->print("\@$name\n");
    $ofh->print("$sequence\n");
    $ofh->print( join("\t",($mate_strand, $chromosome, $mate_position, $ms, $self->tag) ) . "\n");
}

sub parse_one_end {
    my ($self, $line, $line2, $ofh) = @_;
    my ($r1_name, $r1_flag, $r1_chr, $r1_pos, $r1_ms, $r1_is, $r1_seq,) = split /\t/, $line;
    my ($r2_name, $r2_flag, $r2_chr, $r2_pos, $r2_ms, $r2_is, $r2_seq,) = split /\t/, $line2;
    $r1_is = length($r1_seq); 
    $r2_is = length($r2_seq);
    $DB::single=1 if ($r1_ms >0 || $r2_ms > 0);
    
    unless($r2_name eq $r1_name) {
        $self->error_message("Input not sorted with mates next to each other");
        die;
        #is this the right thing to do. should abort the tool here
    }
    
    if(($r1_flag & 0x0004) && ($r2_flag & 0x0004)) {
        return;
        #both unmapped, skip
    }
    elsif($r1_flag & 0x0008 && $r1_ms > 0) {
         #r1 "left" mapped. output right
         if($r2_flag & 0x0010) {
             #forward
             $ofh->print("@" . $r2_name . "\n");
             $ofh->print($r2_seq . "\n");
             $ofh->print("+\t" . $r2_chr . "\t" . ($r2_pos - 1) );
             $ofh->print("\t" . $r2_ms . "\t" . $self->tag . "\n");
         }
         else {
             $ofh->print("@" . $r2_name . "\n");
             $ofh->print($self->reverse_complement($r2_seq) . "\n");
             $ofh->print("-\t" . $r2_chr . "\t" . ($r2_pos - 1 + $r2_is) );
             $ofh->print("\t" . $r2_ms . "\t" . $self->tag . "\n");
             
        }
    }
    elsif($r2_flag & 0x0008 && $r2_ms >0 ) {
         #r2 "right" mapped. output left
         if($r1_flag & 0x0010) {
             #forward
             $ofh->print("@" . $r1_name . "\n");
             $ofh->print($r1_seq . "\n");
             $ofh->print("+\t" . $r1_chr . "\t" . ($r1_pos - 1) );
             $ofh->print("\t" . $r1_ms . "\t" . $self->tag . "\n");
         }
         else {
             $ofh->print("@" . $r1_name . "\n");
             $ofh->print($self->reverse_complement($r1_seq) . "\n");
             $ofh->print("-\t" . $r1_chr . "\t" . ($r1_pos - 1 + $r1_is) );
             $ofh->print("\t" . $r1_ms . "\t" . $self->tag . "\n");
             
        }
    # If the mapped read has mapping score 0, skip it
    } elsif( ($r1_flag & 0x0008 && $r1_ms == 0) || ($r2_flag & 0x0008 && $r2_ms == 0)) {
        return;
    } else {
        $self->error_message("Reached unreachable else block...something's boned.");
        die;
    }
} 
 
sub reverse_complement {
    my $self = shift;
    my $sequence = shift;
    $sequence = reverse $sequence;
    $sequence =~ tr/aAcCtTgG/tTgGaAcC/;
    return $sequence;
}

1;
