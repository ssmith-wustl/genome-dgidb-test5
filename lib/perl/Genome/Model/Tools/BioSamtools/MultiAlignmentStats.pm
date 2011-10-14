package Genome::Model::Tools::BioSamtools::MultiAlignmentStats;

use strict;
use warnings;

use Genome;

my @DEFAULT_HEADERS = qw/
                            total_fragments
                            unmapped_fragments
                            pc_unmapped_fragments
                            mapped_fragments
                            pc_mapped_fragments
                            unique_alignment_fragments
                            pc_unique_alignment_fragments
                            multiple_alignment_fragments
                            pc_multiple_alignment_fragments
                            multiple_alignment_sum
                            multiple_alignment_per_fragment
                        /;

class Genome::Model::Tools::BioSamtools::MultiAlignmentStats {
    is  => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        aligned_bam_file => {
            is => 'String',
            doc => 'A querysorted BAM file containing bwasw alignments.',
        },
        unique_bam_file => {
            is => 'String',
            is_optional => 1,
            doc => 'The path to output the resulting unique alignment BAM file.',
        },
        output_stats_tsv => {
            is => 'String',
            is_optional => 1,
            doc => 'The output stats tsv file name.  If not defined, stats print to STDOUT.',
        },
    ],
    has_optional => {
        _unmapped_reads => { default_value => 0, },
        _unique_reads => { default_value => 0, },
        _multi_reads => { default_value => 0, },
        _multi_alignments => { default_value => 0, },
    },
};

sub help_synopsis {
    return <<EOS
    A bwasw based utility for alignment metrics.
EOS
}

sub help_brief {
    return <<EOS
    A bwasw based utility for alignment metrics.
EOS
}

sub help_detail {
    return <<EOS
Some aligners output multiple alignments per fragment in SAM/BAM format.
This tool is designed to take a queryname sorted, perferably by Picard, SAM/BAM file
and output metrics related to mapped/unmapped fragments and unique/multiple alignments.

Example of STDOUT:

Total Fragments: 940
Unmapped Fragments: 329	35.00%
Mapped Fragments: 611	65.00%
Unique Alignment Fragments: 300	31.91%
Multiple Hit Fragments: 311	33.09%
Multiple Hit Alignment Sum: 995
Multiple Hit Mean per Fragment: 3.20

Example tsv headers:

total_fragments
unmapped_fragments
pc_unmapped_fragments
mapped_fragments
pc_mapped_fragments
unique_alignment_fragments
pc_unique_alignment_fragments
multiple_alignment_fragments
pc_multiple_alignment_fragments
multiple_alignment_sum
multiple_alignment_per_fragment

EOS
}

sub execute {
    my $self = shift;

    # Alignment BAM must be queryname sorted
    my ($aligned_bam,$aligned_header) = $self->validate_sort_order();
    
    # Open unique BAM file if defined
    my $unique_bam_file = $self->unique_bam_file;
    my $unique_bam = undef;
    if ($unique_bam_file) {
        $unique_bam = Bio::DB::Bam->open($unique_bam_file,'w');
        unless ($unique_bam) {
            die('Failed to open output BAM file: '. $unique_bam_file);
        }
        $unique_bam->header_write($aligned_header);
    }

    # Eval alignment objects
    my $previous_aligned_read = $aligned_bam->read1;

    # Avoid a run of unmapped reads at the beginning
    while ($previous_aligned_read->flag & 4) {
        $self->tally_alignments($unique_bam,$previous_aligned_read);
        $previous_aligned_read = $aligned_bam->read1;
    }

    # Iterate over the remaining alignments
    while (my $aligned_read = $aligned_bam->read1) {
        if ($aligned_read->qname eq $previous_aligned_read->qname) {
            # Multiple Alignments per Fragment
            my @alignments = ($previous_aligned_read);
            while ($aligned_read->qname eq $previous_aligned_read->qname) {
                push @alignments, $aligned_read;
                $previous_aligned_read = $aligned_read;
                $aligned_read = $aligned_bam->read1;
            }
            $self->tally_alignments($unique_bam,@alignments);
        } else {
            # Unique Alignment
            $self->tally_alignments($unique_bam,$previous_aligned_read);
        }
        $previous_aligned_read = $aligned_read;
    }

    # Write last alignment if unique
    if ($previous_aligned_read) {
        $self->tally_alignments($unique_bam,$previous_aligned_read);
    }

    # Print stats
    if ($self->output_stats_tsv) {
        $self->print_tsv;
    } else {
        $self->print_stdout;
    }
    
    return 1;
}


sub validate_sort_order {

    my $self = shift;
    my $bam_file = $self->aligned_bam_file;
    
    my $bam = Bio::DB::Bam->open($bam_file);
    unless ($bam) {
        $self->error_message('Failed to open BAM file: '. $bam_file);
        die($self->error_message);
    }
    my $header = $bam->header;
    my $text = $header->text;
    my @lines = split("\n",$text);
    my @hds = grep { $_ =~ /^\@HD/ } @lines;
    if (@hds) {
        unless (scalar(@hds) == 1) {
            $self->error_message('Found multiple HD lines in header: '. "\n\t" . join("\n\t",@hds) ."\nRefusing to continue parsing BAM file: ". $bam_file);
            die($self->error_message);
        }
        my $hd_line = $hds[0];
        if ($hd_line =~ /SO:(\S+)/) {
            my $sort_order = $1;
            unless ($sort_order eq 'queryname') {
                $self->error_message('Input BAM files must be sorted by queryname!  BAM file found to be sorted by \''. $sort_order .'\' in BAM file: '. $bam_file);
                die($self->error_message);
            }
        } else {
            $self->error_message('Input BAM files must be sorted by queryname!  No sort order found for input BAM file: '. $bam_file);
            die($self->error_message);
        }
    } else {
        $self->warning_message('Failed to validate sort order!.  Assuming queryname sorted!');
    }
    return ($bam,$header);
}

sub tally_alignments {
    my $self = shift;
    my $unique_bam = shift;
    my @alignments = @_;

    my $top_alignment;
    for my $alignment (@alignments) {
        if (!defined($top_alignment)) {
            $top_alignment = $alignment;
        } elsif ($alignment->qual > $top_alignment->qual) {
            $top_alignment = $alignment;
        } elsif ($alignment->qual == $top_alignment->qual) {
            if ($alignment->aux_get('AS') > $top_alignment->aux_get('AS')) {
                $top_alignment = $alignment;
            } elsif ($alignment->aux_get('AS') == $top_alignment->aux_get('AS') ) {
                # TODO: determine best method for picking random alignment
                # TODO: use seed to make rand consistent
                $top_alignment = $alignments[rand @alignments];
                # TODO: set mapping quality to zero ?
            }
        }
    }
    if (scalar(@alignments) > 1) {
        $self->multi_mapped(scalar(@alignments));
    } else {
        if ($top_alignment->flag & 4) {
            $self->unmapped;
        } else {
            $self->unique;
        }
    }
    if ($unique_bam) {
        $unique_bam->write1($top_alignment);
    }
    return $top_alignment;
}

sub unmapped {
    my $self = shift;
    my $unmapped = $self->_unmapped_reads;
    $unmapped++;
    $self->_unmapped_reads($unmapped);
    return 1;
}

sub unique {
    my $self = shift;
    my $unique = $self->_unique_reads;
    $unique++;
    $self->_unique_reads($unique);
    return 1;
}

sub multi_mapped {
    my $self = shift;
    my $alignments = shift;

    my $multi = $self->_multi_reads;
    $multi++;
    $self->_multi_reads($multi);

    my $multi_align = $self->_multi_alignments;
    $multi_align += $alignments;
    $self->_multi_alignments($multi_align);
    return 1;
}

sub total_count {
    my $self = shift;
    my $total_reads = ($self->_unmapped_reads + $self->_unique_reads + $self->_multi_reads);
    return $total_reads;
}

sub mapped_count {
    my $self = shift;
    my $mapped_reads = ($self->_unique_reads + $self->_multi_reads);
    return $mapped_reads;
}

sub print_stdout {
    my $self = shift;

    my $total_reads = $self->total_count;
    my $mapped_reads = $self->mapped_count;
    print 'Total Fragments: '. $total_reads ."\n";
    print 'Unmapped Fragments: '. $self->_unmapped_reads ."\t". sprintf("%.02f",( ($self->_unmapped_reads / $total_reads) * 100)) ."%\n";
    print 'Mapped Fragments: '. $mapped_reads ."\t". sprintf("%.02f",( ($mapped_reads / $total_reads) * 100))  ."%\n";
    print 'Unique Alignment Fragments: '. $self->_unique_reads ."\t". sprintf("%.02f",( ($self->_unique_reads / $total_reads) * 100)) ."%\n";
    print 'Multiple Hit Fragments: '. $self->_multi_reads ."\t". sprintf("%.02f",( ($self->_multi_reads / $total_reads) * 100)) ."%\n";
    print 'Multiple Hit Alignment Sum: '.  $self->_multi_alignments ."\n";
    print 'Multiple Hit Mean per Fragment: '.  sprintf("%.02f",($self->_multi_alignments / $self->_multi_reads ))  ."\n";

    return 1;
}

sub headers {
    my $class = shift;
    return \@DEFAULT_HEADERS;
}

sub print_tsv {
    my $self = shift;
    my $tsv_writer = Genome::Utility::IO::SeparatedValueWriter->create(
        headers => $self->headers,
        separator => "\t",
        output => $self->output_stats_tsv,
    );
    unless ($tsv_writer) { die('Failed to open tsv writer: '. $self->output_stats_tsv) };
    my $total_reads = $self->total_count;
    my $mapped_reads = $self->mapped_count;
    my %data = (
        total_fragments => $total_reads,
        unmapped_fragments => $self->_unmapped_reads,
        pc_unmapped_fragments => sprintf("%.02f",( ($self->_unmapped_reads / $total_reads) * 100)),
        mapped_fragments => $mapped_reads,
        pc_mapped_fragments => sprintf("%.02f",( ($mapped_reads / $total_reads) * 100)),
        unique_alignment_fragments => $self->_unique_reads,
        pc_unique_alignment_fragments => sprintf("%.02f",( ($self->_unique_reads / $total_reads) * 100)),
        multiple_alignment_fragments => $self->_multi_reads,
        pc_multiple_alignment_fragments => sprintf("%.02f",( ($self->_multi_reads / $total_reads) * 100)),
        multiple_alignment_sum => $self->_multi_alignments,
        multiple_alignment_per_fragment =>  sprintf("%.02f",($self->_multi_alignments / $self->_multi_reads )),
    );
    $tsv_writer->write_one(\%data);
    $tsv_writer->output->close;
    return 1;
}


1;
