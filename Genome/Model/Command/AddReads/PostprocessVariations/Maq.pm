package Genome::Model::Command::AddReads::PostprocessVariations::Maq;

use strict;
use warnings;

use Genome::Model;
use Genome::Model::Command::Report::MetricsBatchToLsf;
use IO::File;
use File::Basename;

class Genome::Model::Command::AddReads::PostprocessVariations::Maq {
    is => ['Genome::Model::Command::AddReads::PostprocessVariations', 'Genome::Model::Command::MaqSubclasser'],
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


sub _snp_resource_name {
    my $self = shift;
    return sprintf("snips%s", defined $self->ref_seq_id ? "_".$self->ref_seq_id : "");
}

sub _pileup_resource_name {
    my $self = shift;
    return sprintf("pileup%s", defined $self->ref_seq_id ? "_".$self->ref_seq_id : "");
}

sub _genotype_detail_name {
    my $self = shift;
    return sprintf("report_input%s", defined $self->ref_seq_id ? "_".$self->ref_seq_id : "");
}

sub _variation_metrics_name {
    my $self = shift;
    return sprintf("variation_metrics%s", defined $self->ref_seq_id ? "_".$self->ref_seq_id : "");
}

sub snp_output_file {
    my $self = shift;
    return sprintf("%s/identified_variations/%s", $self->model->data_directory,$self->_snp_resource_name);
}

sub pileup_output_file {
    my $self = shift;
    return sprintf("%s/identified_variations/%s", $self->model->data_directory,$self->_pileup_resource_name);
}

sub genotype_detail_file {
    my $self = shift;
    return sprintf("%s/identified_variations/%s", $self->model->data_directory, $self->_genotype_detail_name);
}

sub variation_metrics_file {
    my $self = shift;
    return sprintf("%s/identified_variations/%s", $self->model->data_directory, $self->_variation_metrics_name);
}

sub experimental_variation_metrics_file_basename {
    my $self = shift;
    return sprintf("%s/identified_variations/%s", $self->model->data_directory, 'experimental_' . $self->_variation_metrics_name);
}

sub execute {
    my $self = shift;
    my $model = $self->model;

    $DB::single=1;
    $self->revert;

    unless ($self->generate_variation_metrics_files) {        
        $self->error_message("Error generating variation metrics file (used downstream at filtering time)!");
        # cleanup...
        return;
    }

    unless ($self->generate_genotype_detail_file) {
        $self->error_message("Error generating genotype detail file (annotation input)!");
        # cleanup...
        return;

   }

    unless ($self->verify_successful_completion) {
        $self->error_message("Error validating results!");
        # cleanup...
        return;
    }
    
    return 1;
}

sub verify_successful_completion {
    my $self = shift;
    my $model = $self->model; 

    my $snp_output_file             = $self->snp_output_file;
    my $snp_output_file_count       = _wc($snp_output_file);
    
    my $errors = 0;
    
    my $genotype_detail_file        = $self->genotype_detail_file;
    my $genotype_detail_file_count  = _wc($genotype_detail_file);

    my @ck = map { $self->$_ } qw/variation_metrics_file/;
    for my $ck (@ck) {
        unless (-e $ck) {
            $self->error_message("Failed to find $ck!");
            $errors++;
            next;
        }
        my $cnt = _wc($ck);
        unless ($cnt == $snp_output_file_count) {
            $self->error_message("File $ck has size $cnt "
                    . "while the SNP file $snp_output_file has size $snp_output_file_count!");
            $errors++;
        }
    }
    
    return !$errors;
}

sub _wc {
    my $name = shift;
    my $fh = IO::File->new($name);
    my $cnt = 0;
    while (<$fh>) { $cnt++ }
    return $cnt;
}

sub generate_genotype_detail_file {
    my $self = shift;
    my $model = $self->model; 

    my $snp_resource_name    = $self->_snp_resource_name; 
    my $pileup_resource_name = $self->_pileup_resource_name; 
    my $report_resource_name = $self->_genotype_detail_name; 

    my $snp_output_file     = $self->snp_output_file;
    my $pileup_output_file  = $self->pileup_output_file;
    my $report_input_file   = $self->genotype_detail_file;

    # Get a lock for the snp and pileup files
    foreach my $resource ( $snp_resource_name, $pileup_resource_name, $report_resource_name) {
        unless ($model->lock_resource(resource_id => $resource)) {
            $self->error_message("Can't get lock for resource $resource");
            return undef;
        }
    }

    my $result = $self->_generate_genotype_detail_file($snp_output_file,$pileup_output_file,$report_input_file);
    unless ($result) {
        $self->error_message("Error generating genotype detail!");
        return;
    }

    return $result;
}

sub _generate_genotype_detail_file {
    my ($self, $snp_output_file, $pileup_output_file, $report_input_file) = @_;
    
    foreach my $file ( $snp_output_file, $pileup_output_file) {
        unless (-f $file and -s $file) {
            $self->error_message("File $file dosen't exist or has no data.  It should have been filled-in in a prior step");
            return;
        }
    }

    my $snp_fh = IO::File->new($snp_output_file);
    unless ($snp_fh) {
        $self->error_message("Can't open snp file $snp_output_file: $!");
        return;
    }

    my $pileup_fh = IO::File->new($pileup_output_file);
    unless ($pileup_fh) {
        $self->error_message("Can't open pileup file $pileup_output_file: $!");
        return;
    }

    unlink($report_input_file);
    my $report_fh = IO::File->new(">$report_input_file");
    unless ($report_fh) {
        $self->error_message("Can't open report input file $report_input_file for writing: $!");
        return;
    }

    while(<$snp_fh>) {
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
            #or
            # in the snp file, the max reported read depth is 255
            #$read_depth != ($read_depth >= 255 ? 255 : $pu_read_depth)
        ) {
            
            $self->error_message("Data is not consistent.  snp file line " . $snp_fh->input_line_number . 
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
                                   ), "\n");
            # If the sample is homozygous, only report this SNP once
            last if ($sample_alleles[0] eq $sample_alleles[1]);
        }

    } # end foreach line in the SNP file
                          
    $snp_fh->close();
    $pileup_fh->close();
    $report_fh->close();

    return 1;
}

sub chunk_variation_metrics {
    my $self = shift;
    my %p = (@_);
    my $test_extension = $p{test_extension};
    my $chunk_count = $p{chunk_count} || 20;
    my $model = $self->model;

    my $variation_metrics_file = $self->variation_metrics_file.$test_extension;
    $self->status_message("Generating cross-library metrics for $variation_metrics_file");
    if(1) {
        
        unless (
            Genome::Model::Command::Report::MetricsBatchToLsf->execute
            (
                input => 'resolve '.$self->id,
                snpfile => $self->snp_output_file,
                qual_cutoff => 1,
                output => $variation_metrics_file,
                out_log_file => $self->snp_out_log_file,
                chunk_count => $chunk_count
                #error_log_file => $self->snp_err_log_file,
                # OTHER PARAMS:
                # flank_range => ??,
                # variant_range => ??,
                # format => ??,
            )
        ) {
            $self->error_message("Failed to generate cross-library metrics for $variation_metrics_file");
            return;            
        }
        unless (-s ($variation_metrics_file)) {
            $self->error_message("Metrics file not found for library $variation_metrics_file!");
            return;
        }
    }

    my @libraries = $model->libraries;
    
	$self->status_message("\nGenerating (batch) per-library metric breakdown of $variation_metrics_file");
	foreach my $library_name (@libraries) {
        my $lib_variation_metrics_file = $self->variation_metrics_file . '.' . $library_name.$test_extension;
        $self->status_message("...generating per-library (batch) metrics for $lib_variation_metrics_file");

        unless (
            Genome::Model::Command::Report::MetricsBatchToLsf->execute
            (
                input => 'resolve '.$self->id . " $library_name",
                snpfile => $self->snp_output_file,
                qual_cutoff => 1,
                output => $lib_variation_metrics_file,
                out_log_file => $self->snp_out_log_file,
                chunk_count => $chunk_count,
                #error_log_file => $self->snp_err_log_file,
                # OTHER PARAMS:
                # flank_range => ??,
                # variant_range => ??,
                # format => ??,
            )            
        ) {
            $self->error_message("Failed to generate per-library metrics for $lib_variation_metrics_file");
            return;
        } 
        unless (-s ($lib_variation_metrics_file)) {
            $self->error_message("Per-library (batch) metrics file not found for $lib_variation_metrics_file!");
            return;
        }
    }
    return 1;

}

sub generate_variation_metrics_files {
    my $self = shift;

    my %p = @_;
    my $test_extension = $p{test_extension} || '';

    #if($self->ref_seq_id =~ /^(8|10|1)$/)#horrible hack for now
    #{
    #    return $self->chunk_variation_metrics(@_);
    #}
    #elsif($self->ref_seq_id < 10)
    #{
    #   return $self->chunk_variation_metrics(@_,chunk_count => 3);
    #}
    #else
    #{
    #    return $self->chunk_variation_metrics(@_,chunk_count => 1);
    #}
    my $model = $self->model;

    my $variation_metrics_file = $self->variation_metrics_file.$test_extension;

    my @libraries = $model->libraries;
    
    $self->status_message("\n*** Generating per-library metric breakdown of $variation_metrics_file");
    $self->status_message(join("\n",map { "'$_'" } @libraries));
    foreach my $library_name (@libraries) {
        my $lib_variation_metrics_file = $self->variation_metrics_file . '.' . $library_name.$test_extension;
        $self->status_message("\n...generating per-library metrics for $lib_variation_metrics_file");
        
        my $chromosome_alignment_file = $self->resolve_accumulated_alignments_filename(
            ref_seq_id => $self->ref_seq_id,
            library_name => $library_name,
        ); 
        
        unless (
            $chromosome_alignment_file 
            and -e $chromosome_alignment_file and 
            (-p $chromosome_alignment_file or -s $chromosome_alignment_file)
        ) {
            $self->error_message(
                "Failed to create an accumulated alignments file for"
                . " library_name '$library_name' ref_seq_id " 
                . $self->ref_seq_id    
                . " per-library metrics for library $lib_variation_metrics_file"
            );
            return;
        }
        unless (
            Genome::Model::Tools::Maq::GenerateVariationMetrics->execute(
                input => $chromosome_alignment_file,
                snpfile => $self->snp_output_file,
                qual_cutoff => 1,
                output => $lib_variation_metrics_file
            )
        ) {
            $self->error_message("Failed to (non-batch) generate per-library metrics for $lib_variation_metrics_file");
            return;
        } 
        unless (-s ($lib_variation_metrics_file)) {
            $self->error_message("Per-library metrics (non-batch) file not found or zero size for $lib_variation_metrics_file!");
            return;
        }
    }

    $self->status_message("\n*** Generating cross-library metrics for $variation_metrics_file");
    my $chromosome_alignment_file = $self->resolve_accumulated_alignments_filename(ref_seq_id => $self->ref_seq_id);
    unless (
        Genome::Model::Tools::Maq::GenerateVariationMetrics->execute(
            input => $chromosome_alignment_file,
            snpfile => $self->snp_output_file,
            qual_cutoff => 1,
            output => $variation_metrics_file
        )
    ) {
        $self->error_message("Failed to generate cross-library metrics for $variation_metrics_file");
        return;
    }
    unless (-s ($variation_metrics_file)) {
        $self->error_message("Metrics file not found for library $variation_metrics_file!");
        return;
    }

    return 1;
}

sub generate_experimental_variation_metrics_files {
    # This generates additional bleeding-edge data.
    # It runs directly out of David Larson's home for now until merged w/ the stuff above.
    # It will be removed when bugs are worked out in the regular metric generator.

    my $self = shift;

    my $output_basename     = $self->experimental_variation_metrics_file_basename;
    
    my $snp_file            = $self->snp_output_file;
    my $ref_seq             = $self->ref_seq_id;
    my $map_file            = $self->resolve_accumulated_alignments_filename(); 
    
    # TODO: move this to the model
    my $model = $self->model;
    my $bfa_file = sprintf("%s/all_sequences.bfa", $model->reference_sequence_path);

    my @f = ($map_file,$bfa_file,$snp_file);
    my $errors = 0;
    for my $f (@f) {
        unless (-e $f) {
            $self->error_message("Failed to find file $f");
            $errors++;
        }
    }
    return if $errors;
    my $cmd = "perl /gscuser/dlarson/pipeline_mapstat/snp_stats.pl --mapfile $map_file --ref-bfa $bfa_file --basename 'extra_metrics_$ref_seq' --locfile $snp_file --minq 1 --chr=$ref_seq";
    my $result = system($cmd);
    $result /= 256;
    return $result;
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
# unique reads (by start position) for a given position. 
# If two reads have the same start position, it considers them the same
# if the first 26 bases are the same
sub unique_reads_at_position {
    my($self,$map_fh,$pos) = @_;

    my $last_pos = $self->{'_last_map_pos'} || 0;
    while ($last_pos <= $pos) {
        my $line = $map_fh->getline();
        my @line = split("\t",$line);

        my $start_pos = $line[2];
        $last_pos = $start_pos;
        my $readlen = length($line[14]);   # column 14 is the read data
        my $end_pos = $start_pos + $readlen;
        next if ($end_pos < $pos);   # This read ended before the point we're interested in

        my $sub_sequence;
        if ($readlen > 26) {
            # Quality really drops off after the first 26 bases, so only do our
            # comparisons among those

            if ($line[3] eq '-') {    # 3rd column is the strand 
                # start position is always from the point of view of the forward direction, so
                # for reads on the reverse strand, we need to take the last 26 bases instead of the
                # first 26, and alter the start position to point to the 26th base (from the reverse
                # direction)
                $sub_sequence = uc(substr($line[14], 0, -26));
                $start_pos += ($readlen - 26);
            } else {
                $sub_sequence = uc(substr($line[14], 0, 26));
            }
        } else {
            $sub_sequence = $line[14];
        }

        if (! $self->{'_map_cache_end_pos'}->{$start_pos}) {
            # Haven't had a read at this start pos yet
            $self->{'_map_cache_end_pos'}->{$start_pos} = [ $end_pos ];
            $self->{'_map_cache_sub_sequence'}->{$start_pos} = [ $sub_sequence ];
            $self->{'_map_cache_count'}++;

        } else {
            my $matched = 0;
            # Does the first 26 bases of this read match any of the other 26 bases at this start pos?
            for (my $i = 0; $i < @{$self->{'_map_cache_sub_sequence'}->{$start_pos}}; $i++) {
                if ( $sub_sequence eq $self->{'_map_cache_sub_sequence'}->{$start_pos}->[$i] ) {
                    $matched = 1;
                    last;
                }
            }
            unless ($matched) {
                push @{$self->{'_map_cache_end_pos'}->{$start_pos}}, $end_pos;
                push @{$self->{'_map_cache_sub_sequence'}->{$start_pos}}, $sub_sequence;
                $self->{'_map_cache_count'}++;
            }
        }
    }

    $self->{'_last_map_pos'} = $last_pos;

    # remove any positions that have left the window
    foreach my $key ( keys %{$self->{'_map_cache_end_pos'}} ) {
        next if ($self->{'_map_cache_end_pos'}->{$key} >= $pos);
        delete($self->{'_map_cache_end_pos'}->{$key});
        delete($self->{'_map_cache_sub_sequence'}->{$key});
        $self->{'_map_cache_count'}--;
    }

    # Subtract 1 because we've read in one record past the position we asked for
    return $self->{'_map_cache_count'} - 1;
}

#- LOG FILES -#
sub snp_out_log_file {
    my $self = shift;

    return sprintf
    (
        '%s/%s.out', #'%s/%s_snp.out',
        $self->resolve_log_directory,
        ($self->lsf_job_id || $self->ref_seq_id),
    );
}

sub snp_err_log_file {
    my $self = shift;

    return sprintf
    (
        '%s/%s.err', #'%s/%s_snp.err',
        $self->resolve_log_directory,
        ($self->lsf_job_id || $self->ref_seq_id),
    );
}


 

#sub unique_reads_at_position {
#    my($self,$map_fh,$pos) = @_;
#
#    # fill in new data
#    my $last_pos = $self->{'_last_map_pos'} || 0;
#    while ($last_pos <= $pos) {
#        my $line = $map_fh->getline();
#        my @line = split("\t", $line);
#
#        my $start_pos = $line[2];
#        $last_pos = $start_pos;
#        my $end_pos = $start_pos + length($line[14]);
#        next if ($end_pos < $pos);
#
#        if (! $self->{'_map_cache'}->{$start_pos} or
#              $self->{'_map_cache'}->{$start_pos} < $end_pos) {
#
#            $self->{'_map_cache'}->{$start_pos} = $end_pos;
#        }
#
#    }
#    $self->{'_last_map_pos'} = $last_pos;
#
#    # remove any positions that have left the window
#    foreach my $key ( keys %{$self->{'_map_cache'}} ) {
#        next if ($self->{'_map_cache'}->{$key} >= $pos);
#        delete($self->{'_map_cache'}->{$key});
#    }
#
#    # Subtract 1 because we've read in one record past the position we asked for
#    return scalar(keys(%{$self->{'_map_cache'}}))-1;
#}





1;

