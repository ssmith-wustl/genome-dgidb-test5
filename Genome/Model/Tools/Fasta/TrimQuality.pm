package Genome::Model::Tools::Fasta::TrimQuality;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Tools::Fasta::TrimQuality {
    is  => 'Genome::Model::Tools::Fasta',
    has => [	 
    min_trim_quality => {
        is => 'Int',
        doc => 'Minimum quality value cutoff (10)',
        default => 10,
    },
    min_trim_length => {
        is => 'Int',
        doc => 'Minimum clipped read length (100)',
        default => 100,
    },		 
    ],
};

use Data::Dumper;
require File::Copy;

sub help_brief {
    return 'Trims by FASTA and Quality files by minimum quality and length';
}

sub help_detail { 
    return <<EOS 
EOS
}

sub execute {
    my $self = shift;
    ($self->error_message( 
		      sprintf('Quality file (%s) does not exist.', $self->qual_file)
		      )
     and return)unless -s $self->qual_file;

    my $command = sprintf(
        'trim3 %s -m %s -q %s',# -x 10',
        $self->_fasta_base,
        $self->min_trim_length,
        $self->min_trim_quality,
    );

    if ( system $command ) {
        ($self->error_message("trim3 failed.") and return);
    }

    # Makes a <fasta>.clip and <fasta>.clip.qua, move to file names
    # FASTA
    my $fasta_bak = sprintf('%s.preclip', $self->_fasta_base);
    File::Copy::copy($self->_fasta_base, $fasta_bak)
        or ($self->error_message(sprintf('Can\'t copy %s to %s: %s', $self->_fasta_base, $fasta_bak, $!)) 
	    and return);
    unlink $self->_fasta_base;
    my $fasta_clip = sprintf('%s.clip', $self->_fasta_base);
    File::Copy::copy($fasta_clip, $self->_fasta_base)
        or ($self->error_message( sprintf('Can\'t copy output file (%s) to %s: %s', $fasta_clip, $self->_fasta_base, $!) )
	    and return);
    unlink $fasta_clip;

    # QUAL
    my $qual_bak = sprintf('%s.preclip', $self->qual_base);
    File::Copy::copy($self->qual_base, $qual_bak)
        or ($self->error_message( sprintf('Can\'t copy %s to %s: %s', $self->qual_base, $qual_bak, $!) ) and return);
    unlink $self->qual_base;
    my $qual_clip = sprintf('%s.clip.qual', $self->_fasta_base);
    File::Copy::copy($qual_clip, $self->qual_base)
        or ($self->error_message( sprintf('Can\'t copy output qual file (%s) to %s: %s', $qual_clip, $self->qual_base, $!) ) and return);
    unlink $qual_clip;

    $self->status_message("No sequences made the quality and length cut.") unless -s $self->_fasta_base;

    return 1;
}

1;

#$HeadURL$
#$Id$
