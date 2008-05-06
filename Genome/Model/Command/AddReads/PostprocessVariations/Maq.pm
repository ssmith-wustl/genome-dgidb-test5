package Genome::Model::Command::AddReads::PostprocessVariations::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use IO::File;
use File::Basename;

class Genome::Model::Command::AddReads::PostprocessVariations::Maq {
    is => ['Genome::Model::Event', 'Genome::Model::Command::MaqSubclasser'],
};

sub help_brief {
    "Create the input file required for the annotation report generators"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads postprocess-variations maq --model-id 5 --ref-seq-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
Creates a file with SNP information used later by the annotation report pipeline.

The output file is tab separated and has these columns:
chromosome_name
start position
end position (for SNPs, start and end will be equal)
reference base
sample base
the string 'ref' to indicate the first base above is from the reference
sample variation type ('SNP' for SNP data, later indel data will be something different)
number of sample reads that match the reference
number of sample reads that matched the indicated variant
consensus quality at that position
number of unique reads (by start position) covering that start position

If the sample is homozygous at the SNP position, only one line will be recorded.  If
the sample is heterozygous, there will be two lines with the same start position and
the same reference base.
EOS
}

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";
}

sub should_bsub { 1;}


sub execute {
    my $self = shift;

    my $model = $self->model;

$DB::single=1;
    # Get a lock for the snp and pileup files

    my $snp_resource_name = sprintf("snips%s.filtered",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");
    my $pileup_resource_name = sprintf("pileup%s",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");
    my $report_resource_name = sprintf("report_input%s",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");

    my $snip_output_file = sprintf("%s/identified_variations/%s", $model->data_directory,$snp_resource_name);
    my $pileup_output_file = sprintf("%s/identified_variations/%s", $model->data_directory,$pileup_resource_name);
    my $report_input_file = sprintf("%s/identified_variations/%s", $model->data_directory,$report_resource_name);

    my $chromosome_alignment_file = $model->resolve_accumulated_alignments_filename(ref_seq_id => $self->ref_seq_id);
    my $chromosome_resource_name = basename($chromosome_alignment_file);

    foreach my $file ( $snip_output_file, $pileup_output_file) {
        unless (-f $file and -s $file) {
            $self->error_message("File $file dosen't exist or has no data.  It should have been filled-in in a prior step");
            return;
        }
    }

    foreach my $resource ( $snp_resource_name, $pileup_resource_name, $report_resource_name, $chromosome_resource_name) {
        unless ($model->lock_resource(resource_id => $resource)) {
            $self->error_message("Can't get lock for resource $resource");
            return undef;
        }
    }

    my $snip_fh = IO::File->new($snip_output_file);
    unless ($snip_fh) {
        $self->error_message("Can't open snp file $snip_output_file: $!");
        return;
    }

    my $pileup_fh = IO::File->new($pileup_output_file);
    unless ($pileup_fh) {
        $self->error_message("Can't open pileup file $pileup_output_file: $!");
        return;
    }

    my $report_fh = IO::File->new(">$report_input_file");
    unless ($report_fh) {
        $self->error_message("Can't open report input file $report_input_file for writing: $!");
        return;
    }

    my $maq_pathname = $self->proper_maq_pathname('genotyper_name');
    my $mapview_fh = IO::File->new("$maq_pathname mapview $chromosome_alignment_file |");
    unless ($mapview_fh) {
        $self->error_message("Can't open maq mapview on $chromosome_alignment_file: $!");
        return;
    }

    while(<$snip_fh>) {
        chomp;
        my ($chromosome, $start, $ref_sequence, $cns_sequence, $cns_quality_score,
            $read_depth, $avg_hits, $highest_quality, $allele_quality_diff) = split("\t");

        my $pileup_line = $pileup_fh->getline();
        chomp $pileup_line;
        my ($pu_chromosome, $pu_start, $pu_ref_sequence, $pu_read_depth,
            $pu_reads_info, $pu_reads_qual, $pu_mapping_qual) = split("\t", $pileup_line);

        if ($chromosome ne $pu_chromosome 
            or
            $start != $pu_start 
            or
            $ref_sequence ne $pu_ref_sequence
            or
            # in the snp file, the max reported read depth is 255
            $read_depth != ($read_depth >= 255 ? 255 : $pu_read_depth)) {
            
            $self->error_message("Data is not consistent.  snp file line " . $snip_fh->input_line_number . 
                                 " pileup line " . $pileup_fh->input_line_number);
            return;
        }

        my @sample_alleles = $self->_lookup_iub_code($cns_sequence);

        if (@sample_alleles > 2) {
            # Wha!?  Maq called more than 2 possible alleles?
            # The original code specified that we should report the variation as 'X'
            $sample_alleles[1] = 'X';
        }

        # Count the number of reads resulting in the indicated base
        my %read_counts;
        $read_counts{'A'} = uc($pu_reads_info) =~ tr/A//;
        $read_counts{'C'} = uc($pu_reads_info) =~ tr/C//;
        $read_counts{'G'} = uc($pu_reads_info) =~ tr/G//;
        $read_counts{'T'} = uc($pu_reads_info) =~ tr/T//;

        # And how many reads matched the reference
        my $ref_read_count = $pu_reads_info =~ tr/\.\,//;

        # Write out the SNP info for both alleles (maybe)
        foreach my $i ( 0 .. 1 ) {
            my $sample_read = $sample_alleles[$i];
            next if ($sample_read eq $ref_sequence);

            $report_fh->print(join("\t", $chromosome,   # called 'id' in the original code
                                         $start,        # start position
                                         $start,        # really end, but for SNPs, it's the same
                                         $ref_sequence, # called 'allele1' in the original code
                                         $sample_read,  # called 'allele2' in the original code
                                         'ref',
                                         'SNP',
                                         $ref_read_count,
                                         $read_counts{$sample_read},
                                         $cns_quality_score,
                                         $self->unique_reads_at_position($mapview_fh, $start),
                                   ), "\n");
            # If the sample is homozygous, only report this SNP once
            last if ($sample_alleles[0] eq $sample_alleles[1]);
        }

    } # end foreach line in the SNP file
                          
    $snip_fh->close();
    $pileup_fh->close();
    $report_fh->close();
    $mapview_fh->close();

    return 1;
}



# Converts between the 1-letter genotype code into
# its allele constituients
sub _lookup_iub_code {
    my($self,$code) = @_;

    $self->{'_iub_code_table'} ||= {
             A => ['A', 'A'],
             C => ['C', 'C'],
             G => ['G', 'G'],
             T => ['T', 'T'],
             M => ['A', 'C'],
             K => ['G', 'T'],
             Y => ['C', 'T'],
             R => ['A', 'G'],
             W => ['A', 'T'],
             S => ['G', 'C'],
             D => ['A', 'G', 'T'],
             B => ['C', 'G', 'T'],
             H => ['A', 'C', 'T'],
             V => ['A', 'C', 'G'],
             N => ['A', 'C', 'G', 'T'],
          };
    return @{$self->{'_iub_code_table'}->{$code}};
}


# Given a fh to a whole-lane map file, return a count of the number of 
# unique reads (by start position) for a given position
sub unique_reads_at_position {
    my($self,$map_fh,$pos) = @_;

    # fill in new data
    my $last_pos = $self->{'_last_map_pos'} || 0;
    while ($last_pos <= $pos) {
        my $line = $map_fh->getline();
        my @line = split("\t", $line);

        my $start_pos = $line[2];
        $last_pos = $start_pos;
        my $end_pos = $start_pos + length($line[14]);
        next if ($end_pos < $pos);

        if (! $self->{'_map_cache'}->{$start_pos} or
              $self->{'_map_cache'}->{$start_pos} < $end_pos) {

            $self->{'_map_cache'}->{$start_pos} = $end_pos;
        }

    }
    $self->{'_last_map_pos'} = $last_pos;

    # remove any positions that have left the window
    foreach my $key ( keys %{$self->{'_map_cache'}} ) {
        next if ($self->{'_map_cache'}->{$key} >= $pos);
        delete($self->{'_map_cache'}->{$key});
    }

    # Subtract 1 because we've read in one record past the position we asked for
    return scalar(keys(%{$self->{'_map_cache'}}))-1;
}





1;

