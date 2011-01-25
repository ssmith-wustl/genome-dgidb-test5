package Genome::Model::Tools::BioSamtools::TophatAlignmentStats;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::TophatAlignmentStats {
    is  => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        unaligned_bam_file => {
            is => 'String',
            doc => 'An unaligned BAM file querysorted with ALL reads from original FASTQ files.',
        },
        aligned_bam_file => {
            is => 'String',
            doc => 'A querysorted BAM file containing Tophat alignments.',
        },
        merged_bam_file => {
            is => 'String',
            doc => 'The path to output the resulting merged, unsorted BAM file.',
        },
        alignment_stats_file => {
            is => 'String',
            doc => 'A summary file of some calculated BAM alignment metrics.',
        },
    ],
};

sub help_synopsis {
    return <<EOS
    A Tophat based utility for alignment metrics.
EOS
}

sub help_brief {
    return <<EOS
    A Tophat based utility for alignment metrics.
EOS
}

sub help_detail {
    return <<EOS
--->Add longer docs here<---
EOS
}

sub execute {
    my $self = shift;

    my $unaligned_bam_file = $self->unaligned_bam_file;
    my $aligned_bam_file = $self->aligned_bam_file;
    my $merged_bam_file = $self->merged_bam_file;
    my $output_fh = Genome::Sys->open_file_for_writing($self->alignment_stats_file);
    
    unless ($unaligned_bam_file && $aligned_bam_file && $merged_bam_file) {
        die('Usage:  tophat_alignment_summary.pl <FASTQ_BAM> <TOPHAT_BAM> <MERGED_BAM>');
    }

    #my ($basename, $dirname, $suffix) = File::Basename::fileparse($merged_bam_file,qw/\.bam/);
    #my ($tmp_fh, $tmp_merged_bam_file) = tempfile($basename.'_XXXX',SUFFIX => $suffix, TMPDIR=>1);
    #$tmp_fh->close;

    my $merged_bam = Bio::DB::Bam->open($merged_bam_file,'w');
    unless ($merged_bam) {
        die('Failed to open output BAM file: '. $merged_bam_file);
    }

    my ($unaligned_bam,$unaligned_header) = validate_sort_order($unaligned_bam_file);

    my ($aligned_bam,$aligned_header) = validate_sort_order($aligned_bam_file);
    &validate_aligned_bam_header($aligned_header);
    $merged_bam->header_write($aligned_header);
    
    my $target_names = $aligned_header->target_name;
    my %chr_hits;
    my $total_reads = 0;
    my $unmapped_count = 0;
    my $previous_aligned_read_name = '';
    while (my $aligned_read = $aligned_bam->read1) {
        my $aligned_flag = $aligned_read->flag;
        my $aligned_read_qname = $aligned_read->qname;
        my $aligned_read_end = 0;
        if ($aligned_flag & 1) {
            if ($aligned_flag & 64) {
                $aligned_read_end = 1;
            } elsif ($aligned_flag & 128) {
                $aligned_read_end = 2;
            } else {
                die ('Lost read pair info for: '. $aligned_read_qname);
            }
        }
        unless ($aligned_flag & 4) {
            my $num_hits  = $aligned_read->aux_get('NH');
            unless (defined($num_hits)) { die ('Failed to parse NH tag from BAM file: '. $aligned_bam_file); }
            # TODO: check mate chr and look for discordant pairs
            my $chr = $target_names->[$aligned_read->tid];
            if ($num_hits == 1) {
                $chr_hits{$chr}{'top'}++;
                if ($aligned_read->cigar_str =~ /N/) {
                    $chr_hits{$chr}{'top_spliced'}++;
                }
            } elsif ($num_hits > 1) {
                $chr_hits{$chr}{'multi'}{$aligned_read_qname .'/'. $aligned_read_end} += $num_hits;
                if ($aligned_read->cigar_str =~ /N/) {
                    $chr_hits{$chr}{'multi_spliced'}{$aligned_read_qname .'/'. $aligned_read_end}++;
                }
            } else {
                die('No hits found for '. $aligned_read_qname .'!  Please add support for unaligned reads.');
            }
        } else {
            die('Please add support for unaligned read found in Tophat BAM: '. $aligned_bam_file);
        }
        my $aligned_read_name = $aligned_read_qname .'/'. $aligned_read_end;
        if ($aligned_read_name eq $previous_aligned_read_name) {
            next;
        }
        my $unaligned_read = $unaligned_bam->read1;
        my $unaligned_flag = $unaligned_read->flag;
        my $unaligned_read_end;
        if ($unaligned_flag & 64 ) {
            $unaligned_read_end = 1;
        } elsif ( $unaligned_flag & 128 ) {
            $unaligned_read_end = 2;
        }
        my $unaligned_read_name = $unaligned_read->qname .'/'. $unaligned_read_end;
        while ($unaligned_read_name ne $aligned_read_name) {
            $unmapped_count++;
            $total_reads++;
            $merged_bam->write1($unaligned_read);
            $unaligned_read = $unaligned_bam->read1;
            $unaligned_flag = $unaligned_read->flag;
            if ($unaligned_flag & 64 ) {
                $unaligned_read_end = 1;
            } elsif ( $unaligned_flag & 128 ) {
                $unaligned_read_end = 2;
            }
            $unaligned_read_name = $unaligned_read->qname .'/'. $unaligned_read_end;
        }
        $total_reads++;
        $merged_bam->write1($aligned_read);
        $previous_aligned_read_name = $aligned_read_name;
    }

    # Write the remaining unaligned reads
    while (my $unaligned_read = $unaligned_bam->read1) {
        $unmapped_count++;
        $total_reads++;
        $merged_bam->write1($unaligned_read);
    }

    # sort by chr position putting unmapped reads at end of BAM
    # A call to samtools or picard may be faster/more efficient
    #Bio::DB::Bam->sort_core(0,$tmp_merged_bam_file,$dirname.'/'.$basename,4000);
    #unlink($tmp_merged_bam_file) || die('Failed to remove temp BAM file: '. $tmp_merged_bam_file);
    
    print $output_fh "chr\ttop\ttop-spliced\tpct_top_spliced\tmulti_reads\tpct_multi_reads\tmulti_spliced_reads\tpct_multi_spliced_reads\tmulti_hits\n";
    my $total_mapped;
    my $total_top_hits;
    for my $chr (sort keys %chr_hits) {
        my $top_hits = $chr_hits{$chr}{'top'} || 0;
        $total_mapped += $top_hits;
        $total_top_hits += $top_hits;
        my $top_spliced = $chr_hits{$chr}{'top_spliced'} || 0;
        my $pct_top_spliced = 0;
        if ($top_hits) {
            $pct_top_spliced = sprintf("%.02f",(($top_spliced / $top_hits) * 100));
        }
        my $multi_reads = 0;
        my $multi_hits = 0;
        for my $read (keys %{$chr_hits{$chr}{'multi'}}) {
            $multi_reads++;
            $multi_hits += $chr_hits{$chr}{'multi'}{$read};
        }
        $total_mapped += $multi_reads;
        my $multi_spliced_reads = scalar(keys %{$chr_hits{$chr}{'multi_spliced'}}) || 0;
        my $pct_multi_hit_reads = 0;
        my $pct_multi_spliced_reads = 0;
        if ($multi_reads) {
            $pct_multi_hit_reads = sprintf("%.02f",( ( $multi_reads / ($multi_reads + $top_hits) ) * 100 ));
            $pct_multi_spliced_reads = sprintf("%.02f",( ( $multi_spliced_reads / ($multi_reads) ) * 100 ));
        }
        print $output_fh $chr ."\t". $top_hits ."\t". $top_spliced ."\t". $pct_top_spliced ."\t". $multi_reads ."\t". $pct_multi_hit_reads
            ."\t". $multi_spliced_reads ."\t". $pct_multi_spliced_reads ."\t". $multi_hits ."\n";
    }

    print $output_fh '##Total Reads: '. $total_reads ."\n";
    print $output_fh '##Unmapped Reads: '. $unmapped_count ."\n";
    print $output_fh '##Unique Alignments: '. $total_top_hits ."\n";
    print $output_fh '##Total Reads Mapped: '. $total_mapped ."\n";
    $output_fh->close;
    return 1;
}


sub validate_sort_order {
    my $bam_file = shift;
    my $bam = Bio::DB::Bam->open($bam_file);
    unless ($bam) {
        die('Failed to open BAM file: '. $bam_file);
    }
    my $header = $bam->header;
    my $text = $header->text;
    my @lines = split("\n",$text);
    my @hds = grep { $_ =~ /^\@HD/ } @lines;
    unless (scalar(@hds) == 1) {
        die('Found multiple HD lines in header: '. "\n\t" . join("\n\t",@hds)) ."\nRefusing to continue parsing BAM file: ". $bam_file;
    }
    my $hd_line = $hds[0];
    if ($hd_line =~ /SO:(\S+)/) {
        my $sort_order = $1;
        unless ($sort_order eq 'queryname') {
            die('Input BAM files must be sorted by queryname!  BAM file found to be sorted by \''. $sort_order .'\' in BAM file: '. $bam_file);
        }
    } else {
        die('Input BAM files must be sorted by queryname!  No sort order found for input BAM file: '. $bam_file);
    }
    return ($bam,$header);
}

sub validate_aligned_bam_header {
    my $header = shift;
    my $text = $header->text;
    my @lines = split("\n",$text);
    my @pgs = grep { $_ =~ /^\@PG/ } @lines;
    unless (scalar(@pgs) == 1) {
        die('Found multiple PG lines in header: '. "\n\t". join("\n\t",@pgs) ."\nRefusing to continue parsing header.");
    }
    my $pg_line = $pgs[0];
    if ($pg_line =~ /ID:(\S+)/) {
        my $program = $1;
        unless ($program eq 'TopHat') {
            die('Input aligned BAM file must be aligned with Tophat!');
        }
    } else {
        die('Input aligned BAM file has no defined aligner program');
    }
    return 1;
}


1;
