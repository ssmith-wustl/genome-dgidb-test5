package Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Maq;

#REVIEW fdu
#short:
#1. Fix help_synopsis
#2. replace lookup_iub_code with calling class method in Genome::Indo::IUB
#3. replace generate_genotype_detail_file subroutine with G::M::T::Snp::GenotypeDetail
#4. Change to get ref_seq_file via reference_build->full_consensus_path('bfa')
#5. No need to list analysis_base_path, snp_output_file ... as properties
#and do calculation there. They should be moved down to the body of execute and 
#resolved their values there.
#
#Long:
#1. Currently, the snp and indel ouputs generated from this are not
#much useful to MG. The key file "filtered.indelpe.snps" is produced
#during the step of RunReports via calling '_snv_file_filtered' method
#od G::M::B::RefAlign::Solexa (check my review there), which makes no sense. That 
#chunk of codes should be moved from there to here and replace current varaint calling process.


use strict;
use warnings;

use Genome;

use File::Path;
use Data::Dumper;
use File::Temp;
use IO::File;

class Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Maq {
    is => ['Genome::Model::Command::Build::ReferenceAlignment::FindVariations'],
    has => [
        analysis_base_path => {
                               doc => "the path at which all analysis output is stored",
                               calculate_from => ['build'],
                               calculate => q|
                                   return $build->snp_related_metric_directory;
                               |,
                               is_constant => 1,
                           },
        snp_output_file => {
                            doc => "",
                            calculate_from => ['analysis_base_path','ref_seq_id'],
                            calculate => q|
                                return $analysis_base_path .'/snps_'. $ref_seq_id;
                            |,
                        },
        indel_output_file => {
                              doc => "",
                              calculate_from => ['analysis_base_path','ref_seq_id'],
                              calculate => q|
                                  return $analysis_base_path .'/indels_'. $ref_seq_id;
                              |,
                          },
        pileup_output_file => {
                               doc => "",
                               calculate_from => ['analysis_base_path','ref_seq_id'],
                               calculate => q|
                                   return $analysis_base_path .'/pileup_'. $ref_seq_id;
                               |,
                           },
        filtered_snp_output_file => {
                                     doc => "",
                                     calculate_from => ['snp_output_file'],
                                     calculate => q|
                                         return $snp_output_file .'.filtered';
                                     |,
                                 },
        genotype_detail_file => {
                                 doc => "",
                                 calculate_from => ['analysis_base_path','ref_seq_id'],
                                 calculate => q|
                                     return $analysis_base_path .'/report_input_'. $ref_seq_id;
                                 |,
                             },
    ],
};

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

sub help_brief {
    "Use maq to find snps and idels"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads find-variations maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the postprocess-alignments process
EOS
}

sub execute {
    my $self = shift;

    my $model = $self->model;
    my $build = $self->build;

    my $maq_pathname = Genome::Model::Tools::Maq->path_for_maq_version($model->indel_finder_version);
    my $maq_pl_pathname = Genome::Model::Tools::Maq->proper_maq_pl_pathname($model->indel_finder_version);

    # ensure the reference sequence exists.
    my $ref_seq_file = $model->reference_sequence_path . "/all_sequences.bfa";
    unless ($self->check_for_existence($ref_seq_file)) {
        $self->error_message("reference sequence file $ref_seq_file does not exist.  please verify this first.");
        return;
    }

    unless (-d $self->analysis_base_path) {
        unless($self->create_directory($self->analysis_base_path)) {
            $self->error_message("Failed to create directory: " . $self->analysis_base_path . " (check permissions...)");
            return;
        }
        chmod 02775, $self->analysis_base_path;
    }

    my ($assembly_output_file) =  $build->_consensus_files($self->ref_seq_id);
    unless ($self->check_for_existence($assembly_output_file)) {
        $self->error_message("Assembly output file $assembly_output_file was not found.  It should have been created by a prior run of update-genotype-probabilities maq");
        return;
    }

    my $snp_output_file =  $self->snp_output_file;
    my $filtered_snp_output_file = $self->filtered_snp_output_file;
    my $indel_output_file =  $self->indel_output_file;
    my $pileup_output_file = $self->pileup_output_file;

    # Remove the result files from any previous run
    unlink($snp_output_file,$filtered_snp_output_file,$indel_output_file,$pileup_output_file);

    my $retval = system("$maq_pathname cns2snp $assembly_output_file > $snp_output_file");
    unless ($retval == 0) {
        $self->error_message("running maq cns2snp returned non-zero exit code $retval");
        return;
    }

    $retval = system("$maq_pl_pathname SNPfilter $snp_output_file > $filtered_snp_output_file");
    unless ($retval == 0) {
        $self->error_message("running maq.pl SNPfilter returned non-zero exit code $retval");
        return;
    }

    my $accumulated_alignments = $build->whole_rmdup_map_file;
    $retval = system("$maq_pathname indelsoa $ref_seq_file $accumulated_alignments > $indel_output_file");
    unless ($retval == 0) {
        $self->error_message("running maq indelsoa returned non-zero exit code $retval");
        return;
    }
    
    # Running pileup requires some parsing of the snp file
    my $tmpfh = File::Temp->new();
    my $snp_fh = IO::File->new($snp_output_file);
    unless ($snp_fh) {
        $self->error_message("Can't open snp output file for reading: $!");
        return;
    }
    while(<$snp_fh>) {
        chomp;
        my ($id, $start, $ref_sequence, $iub_sequence, $quality_score,
            $depth, $avg_hits, $high_quality, $unknown) = split("\t");
        $tmpfh->print("$id\t$start\n");
    }
    $tmpfh->close();
    $snp_fh->close();

    my $pileup_command = sprintf("$maq_pathname pileup -v -l %s %s %s > %s",
                                 $tmpfh->filename,
                                 $ref_seq_file,
                                 $accumulated_alignments,
                                 $pileup_output_file);

    $retval = system($pileup_command);
    unless ($retval == 0) {
        $self->error_message("running maq pileup returned non-zero exit code $retval");
        return;
    }

    unless ($self->generate_genotype_detail_file) {
        $self->error_message("Error generating genotype detail file (annotation input)!");
        return;
    }

    unless ($self->generate_metrics) {
        $self->error_message("Error generating metrics.");
        return;
    }

    return $self->verify_successful_completion;
}

sub generate_metrics {
    my $self = shift;

    my @m = $self->metrics;
    for (@m) { $_->delete };

    my $snp_output_file = $self->snp_output_file;
    my $snp_fh = IO::File->new($snp_output_file);
    my $snp_count = 0;
    my $snp_count_filtered = 0;
    while (my $row = $snp_fh->getline) {
        $snp_count++;
        my ($r,$p,$a1,$a2,$q,$c) = split(/\s+/,$row);
        $snp_count_filtered++ if $q >= 15 and $c > 2;
        
    }
    $self->add_metric(name => 'total_snp_count', value => $snp_count);
    $self->add_metric(name => 'confident_snp_count', value => $snp_count_filtered);

    my $indel_output_file = $self->indel_output_file;
    my $indel_fh = IO::File->new($indel_output_file);
    my $indel_count = 0;
    while (my $row = $indel_fh->getline) {
        $indel_count++;
        
    }
    $self->add_metric(name => 'total indel count', value => $indel_count);
    print "$self->{ref_seq_id}\t$snp_count\t$snp_count_filtered\t$indel_count\n";

    return 1;
}

sub verify_successful_completion {
    my $self = shift;

    for my $file ($self->snp_output_file, $self->pileup_output_file) {
        unless (-e $file && -s $file) {
           $self->error_message("file does not exist or is zero size $file");
            return;
        }
    }
    for my $file ($self->filtered_snp_output_file, $self->indel_output_file) {
         unless (-e $file )  {
           $self->error_message("file does not exist or is zero size $file");
            return;
        }
    }

    return 1;
}

sub generate_genotype_detail_file {
    my $self = shift;
    my $model = $self->model; 

    my $snp_output_file     = $self->snp_output_file;
    my $pileup_output_file  = $self->pileup_output_file;
    my $report_input_file   = $self->genotype_detail_file;

   
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


1;

