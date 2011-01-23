package Genome::Model::Tools::Sam::VarFilter;

use strict;
use warnings;

use Genome;
use IO::File;

use File::Temp;
use File::Basename;


my %options = (
    min_map_qual_snp => {
        is  => 'Integer',
        doc => '-Q minimum RMS mapping quality for SNPs, default 25',
        default => 25,
    },
    min_map_qual_gap => {
        is  => 'Integer',
        doc => '-q minimum RMS mapping quality for gaps, default 10',
        default => 10,
    },
    min_read_depth => {
        is  => 'Integer',
        doc => '-d minimum read depth, default 3',
        default => 3,
    },
    max_read_depth => {
        is  => 'Integer',
        doc => '-D maximum read depth, default 100000000',
        default => 100000000,
    },
    snp_win_size => {
        is  => 'Integer',
        doc => '-W window size for filtering dense SNPs, default 10',
        default => 10,
    },
    gap_win_size => {
        is  => 'Integer',
        doc => '-l window size for filtering adjacent gaps, default 30',
        default => 30,
    },
    gap_nearby_size => {
        is  => 'Integer',
        doc => '-w SNP within INT bp around a gap to be filtered, default 10',
        default => 10,
    },
    max_snp_per_win => {
        is  => 'Integer',
        doc => '-N maximum number of SNPs in a sized window',
        default => 2,
    },
    min_indel_score => {
        is  => 'Integer',
        doc => '-G minimum indel score for nearby SNP filtering, default is 25',
        default => 25,
    },
);

my %other_options = (
    filtered_snp_out_file => {
        is  => 'String',
        doc => 'snp output file after filter',
        default => 'snp.varfilter',
    },
    filtered_indel_out_file => {
        is  => 'String',
        doc => 'snp output file after filter',
        default => 'indel.varfilter',
    },
);


class Genome::Model::Tools::Sam::VarFilter {
    is  => 'Genome::Model::Tools::Sam',
    has => [
        bam_file => {
            is  => 'String',
            doc => 'The input bam file',
        },
        ref_seq_file => {
            is  => 'String',
            doc => 'reference sequence file used for samtools pileup',
        },
    ],
    has_optional => [%options, %other_options],
};


sub help_brief {
    'Filter samtools-pileup snp indel output. This uses samtools pileup and samtools varFilter pipe together';
}

sub help_detail {
    return <<EOS
    Filter samtools-pileup snp indel output.
EOS
}


sub execute {
    my $self = shift;
    my $bam_file = $self->bam_file;
    my $ref_seq  = $self->ref_seq_file;
    my $sam_path = $self->samtools_path;
    
    my $dir = dirname $self->filtered_snp_out_file;
    
    unless (-s $bam_file and -s $ref_seq) {
        $self->error_message("Can not find valid bam file: $bam_file or valid ref seq: $ref_seq");
        return;
    }
    
    my (undef, $tmp_bam) = File::Temp::tempfile(
        'tmpBamXXXXXX', 
        UNLINK => 1,
        DIR    => $dir,
    );
    
    my $view_cmd = "$sam_path view -b -q 1 $bam_file -o $tmp_bam";

    my $rv = Genome::Sys->shellcmd(
        cmd => $view_cmd,
        output_files => [$tmp_bam],
        skip_if_output_is_present => 0,
    );

    unless ($rv == 1) {
        $self->error_message("Failed to run command: $view_cmd");
        return;
    }
    
    my ($tmp_fh, $tmp_out) = File::Temp::tempfile(
        'varFilterXXXXXX', 
        UNLINK => 1,
        DIR    => $dir,
    );
    
    my $pileup_cmd = sprintf('%s pileup -f %s -c %s', $sam_path, $ref_seq, $tmp_bam);
    
    my $filter_cmd = $self->samtools_pl_path . ' varFilter';

    for my $option (keys %options) {
        if (defined $self->$option) {
            my ($opt) = $options{$option}->{doc} =~ /^(\-\S)\s/;
            $filter_cmd .= " $opt " . $self->$option;
        }
    }

    $filter_cmd .= " - > $tmp_out";

    my $cmd = $pileup_cmd . ' | '. $filter_cmd;
    
    $rv = Genome::Sys->shellcmd(
        cmd => $cmd,
        output_files => [$tmp_out],
        skip_if_output_is_present => 0,
    );
        
    unless ($rv == 1) {
        $self->error_message("Failed to run command: $cmd");
        return;
    }

    my $snp_out_fh   = Genome::Sys->open_file_for_writing($self->filtered_snp_out_file) or return;
    my $indel_out_fh = Genome::Sys->open_file_for_writing($self->filtered_indel_out_file) or return;

    while (my $line = $tmp_fh->getline) {
        my ($id) = $line =~ /^\S+\s+\S+\s+(\S+)\s+/;
        if ($id eq '*') {
            $indel_out_fh->print($line);
        }
        else {
            $snp_out_fh->print($line);
        }
    }
    
    $tmp_fh->close;
    $snp_out_fh->close;
    $indel_out_fh->close;
    
    return 1;
}
    

1;
