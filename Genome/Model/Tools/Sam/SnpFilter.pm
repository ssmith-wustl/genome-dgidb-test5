package Genome::Model::Tools::Sam::SnpFilter;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Sam::SnpFilter {
    is  => 'Command',
    has => [
        snp_file => {
            is  => 'String',
            doc => 'The input sam/bam snp file',
        },
    ],
    has_optional => [
        max_map_qual => {
            is  => 'Integer',
            doc => 'max mapping quality of the reads covering the SNP, default 40',
            default => 40,
        },
        min_cns_qual => {
            is  => 'Integer',
            doc => 'minimum consensus quality, default 20',
            default => 20,
        },
        min_read_depth => {
            is  => 'Integer',
            doc => 'minimum read depth to call a SNP, default 3',
            default => 3,
        },
        max_read_depth => {
            is  => 'Integer',
            doc => 'maximum read depth to call a SNP, default 256',
            default => 256,
        },
        window_size => {
            is  => 'Integer',
            doc => 'window size for filtering dense SNPs, default 10',
            default => 10,
        },
        max_snp_per_win => {
            is  => 'Integer',
            doc => 'maximum number of SNPs in a sized window',
            default => 2,
        },
        out_file => {
            is  => 'String',
            doc => 'snp output file after filter',
        },
    ],
};


sub help_brief {
    'Filter samtools-pileup snp output';
}

sub help_detail {
    return <<EOS
    Filter samtools-pileup snp output. The idea was borrowed from maq.pl SNPfilter.
    Filters are set for read depth, mapping quality, consensus quality, snp dense per
    window
EOS
}



sub execute {
    my $self = shift;
    my $snp_file = $self->snp_file;
    
    unless (-s $snp_file) {
        $self->error_message('Can not find valid SAM snp file: '.$snp_file);
        return;
    }
    
    my @snps = ();
    my $last_chr = '';
    
    my $out_file = $self->out_file || $self->snp_file . '.sam_SNPfilter';
    my $out_fh = Genome::Utility::FileSystem->open_file_for_writing($out_file) or return;
    my $snp_fh = Genome::Utility::FileSystem->open_file_for_reading($snp_file) or return;
    
    while (my $line = $snp_fh->getline) {
        my ($chr, $pos, $cns_qual, $map_qual, $rd_depth) = $line =~ /^(\S+)\s+(\S+)\s+\S+\s+\S+\s+(\S+)\s+\S+\s+(\S+)\s+(\S+)\s+/;
        next unless $cns_qual >= $self->min_cns_qual and $map_qual >= $self->max_map_qual and $rd_depth >= $self->min_read_depth and $rd_depth <= $self->max_read_depth;
        
        if ($chr ne $last_chr) {
            map{$out_fh->print($_->{line}) if $_->{flag}}@snps;
            @snps = ();       #reset
            $last_chr = $chr; #reset
        }

        push @snps, {
            line => $line,
            pos  => $pos,
            flag => 1,
        };

        if ($#snps == $self->max_snp_per_win) {
            if ($snps[$#snps]->{pos} - $snps[0]->{pos} < $self->window_size) {
                map{$_->{flag} = 0}@snps;
            }
            $out_fh->print($snps[0]->{line}) if $snps[0]->{flag};
            shift @snps; # keep the size of @snps, moving the window snp by snp, check the snp density in a window for all snps.
        }
    }
    map{$out_fh->print($_->{line}) if $_->{flag}}@snps;

    $snp_fh->close;
    $out_fh->close;
    
    return 1;
}


1;
