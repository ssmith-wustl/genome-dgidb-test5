package Genome::Model::Tools::Sam::IndelFilter;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Sam::IndelFilter {
    is  => 'Command',
    has => [
        indel_file => {
            is  => 'String',
            doc => 'The input samtools pileup indel file',
        },
    ],
    has_optional => [
        out_file       => {
            is  => 'String',
            doc => 'The filtered output indel file',
        },
        max_read_depth => {
            is  => 'Integer',
            doc => 'maximum read depth, default 100',
            default => 100,
        },
        min_win_size   => {
            is  => 'Integer',
            doc => 'minimum distance between two adjacent indels, default 10',
            default => 10,
        },
        scaling_factor => {
            is  => 'Integer',
            doc => 'scaling factor in score calculation, default 100',
            default => 100,
        },
        is_ref         => {
            is  => 'Boolean',
            doc => 'reference flag, default 0',
            default => 0,
        },
    ],
};


sub help_brief {
    'Filter samtools-pileup indel output';
}

sub help_detail {
    return <<EOS
    Filter samtools-pileup indel output. The idea was borrowed from samtools.pl indelfilter.
    Filters are set for max read depth, min window size, scaling dactor and is_ref flag
EOS
}


sub execute {
    my $self = shift;
    
    my $indel_file = $self->indel_file;
    my $is_ref     = $self->is_ref ? 1 : 0;

    unless (-e $indel_file) {
        $self->error_message('Can not find valid SAM indel file: '.$indel_file);
        return;
    }
    
    my @curr = ();
    my @last = ();

    my $out_file = $self->out_file || $self->indel_file . '.filtered';
    my $out_fh   = Genome::Sys->open_file_for_writing($out_file)   or return;
    my $indel_fh = Genome::Sys->open_file_for_reading($indel_file) or return;
    
    while (my $indel = $indel_fh->getline) {
        my @items = split /\s+/, $indel;
        my ($chr, $pos, $id, $indel_detail, $score, $rd_depth, $indel_seq1, $indel_seq2, $subscore1, $subscore2) = map{$items[$_]}(0..3, 5, 7..11);
        
        next unless $id eq '*';
        next if $rd_depth > $self->max_read_depth;
        
        #In rare case, indel line will get something like follows (RT#62927):
        #NT_113915	187072	*	-	/-		18	0	33	32	-		*	3	29	0	0	0
        if ($indel_detail eq '-') {
            $self->warning_message("Indel line: $indel gets invalid format. Skip");
            next;
        }

        unless ($is_ref) {
            next if $indel_detail eq '*/*';
            next if $score == 0;
        }
        
        $score += $self->scaling_factor * $subscore1 unless $indel_seq1 eq '*';
        $score += $self->scaling_factor * $subscore2 unless $indel_seq2 eq '*';

        @curr = ($chr, $pos, $score, $indel);
        my $do_swap = 1;

        if (defined $last[0]) {
	        if ($curr[0] eq $last[0] && $last[1] + $self->min_win_size > $curr[1]) {
		        $do_swap = 0 if $last[2] > $curr[2];
	        } 
            else {
		        $out_fh->print($last[3]);
            }
        }
	    if ($do_swap) {
	        my @tmp = @curr; 
            @curr = @last; 
            @last = @tmp;
	    }
    }
    $out_fh->print($last[3]) if defined $last[0];
    
    $indel_fh->close;
    $out_fh->close;
    
    return 1;
}


1;
