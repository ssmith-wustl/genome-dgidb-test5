package Genome::Model::Tools::Snp::Sort;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Sort::Naturally qw| nsort |;

class Genome::Model::Tools::Snp::Sort {
    is => 'Command',
    has => [
    snp_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "maq cns2snp output",
    },
    ]
};



sub execute {
    my $self=shift;

    #Check on the file names
    unless(-f $self->snp_file) {
        $self->error_message("Snps file is not a file: " . $self->snp_file);
        return;
    }

    #Check and open filehandles
    my $snp_fh=IO::File->new($self->snp_file);
    unless($snp_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->snp_file );
        return;
    }
    my %snp_at;
    
    while(my $line = $snp_fh->getline) {
        my ($chr, $pos,) = split /\t/, $line;
        $snp_at{$chr}{$pos} = $line;
    }

    for my $chr (nsort keys %snp_at) {
        for my $pos (sort { $a <=> $b } keys %{$snp_at{$chr}}) {
            print $snp_at{$chr}{$pos};
        }
    }
    
    return 1;
}

    


1;

sub help_brief {
    "Sorts a SNP file using Sort::Naturally to sort the chromosomes";
}

sub help_detail {
}



    
