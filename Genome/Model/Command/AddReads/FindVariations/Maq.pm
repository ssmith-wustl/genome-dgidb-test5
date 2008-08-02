package Genome::Model::Command::AddReads::FindVariations::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;
use File::Temp;
use IO::File;

class Genome::Model::Command::AddReads::FindVariations::Maq {
    is => [
           'Genome::Model::Command::AddReads::FindVariations',
           'Genome::Model::Command::MaqSubclasser'
       ],
    has => [
        analysis_base_path => {
            doc => "the path at which all analysis output is stored",
            calculate_from => ['model'],
            calculate => q|
                return $model->data_directory. "/identified_variations";
            |,
            is_constant => 1,
        },
        snip_resource_name => {
            doc => "basename of the snp output file as well as resource lock name",
            calculate_from => ['ref_seq_id'],
            calculate => q|
                return sprintf("snips%s",defined $ref_seq_id ? "_". $ref_seq_id : "");
            |,
        },
        indel_resource_name => {
            doc => "basename of the indel output file as well as resource lock name",
            calculate_from => ['ref_seq_id'],
            calculate => q|
                return sprintf("indels%s",defined $ref_seq_id ? "_". $ref_seq_id : "");
            |,
        },
        pileup_resource_name => {
            doc => "basename of the pileup output file as well as resource lock name",
            calculate_from => ['ref_seq_id'],
            calculate => q|
                return sprintf("pileup%s",defined $ref_seq_id ? "_". $ref_seq_id : "");
            |,
        },
        snip_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path','snip_resource_name'],
            calculate => q|
                return $analysis_base_path ."/". $snip_resource_name;
            |,
        },
        filtered_snip_output_file => {
            doc => "",
            calculate_from => ['snip_output_file'],
            calculate => q|
                return $snip_output_file .".filtered";
            |,
        },
        indel_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path','indel_resource_name'],
            calculate => q|
                return $analysis_base_path ."/". $indel_resource_name;
            |,
        },
        pileup_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path','pileup_resource_name'],
            calculate => q|
                return $analysis_base_path ."/". $pileup_resource_name;
            |,
        },
    ],
};

# TODO: move above
sub _genotype_detail_name {
    my $self = shift;
    return sprintf("report_input%s", defined $self->ref_seq_id ? "_".$self->ref_seq_id : "");
}
sub genotype_detail_file {
    my $self = shift;
    return sprintf("%s/identified_variations/%s", $self->model->data_directory, $self->_genotype_detail_name);
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



sub help_brief {
    "Use maq to find snips and idels"
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

sub bsub_rusage { return "-R 'select[type=LINUX64] span[hosts=1]'"; } 

sub execute {
    my $self = shift;

    my $model = $self->model;

    my $maq_pathname = $self->proper_maq_pathname('indel_finder_name');
    my $maq_pl_pathname = $self->proper_maq_pl_pathname('indel_finder_name');

    # ensure the reference sequence exists.
    my $ref_seq_file = $model->reference_sequence_path . "/all_sequences.bfa";
    unless (-e $ref_seq_file) {
        $self->error_message("reference sequence file $ref_seq_file does not exist.  please verify this first.");
        return;
    }

    unless (-d $self->analysis_base_path) {
        mkdir($self->analysis_base_path);
        chmod 02775, $self->analysis_base_path;
    }

    my ($assembly_output_file) =  $model->assembly_file_for_refseq($self->ref_seq_id);
    unless (-f $assembly_output_file) {
        $self->error_message("Assembly output file $assembly_output_file was not found.  It should have been created by a prior run of update-genotype-probabilities maq");
        return;
    }

    foreach my $resource ( $self->snip_resource_name, $self->indel_resource_name, $self->pileup_resource_name) {
        unless ($model->lock_resource(resource_id=>$resource)) {
            $self->error_message("Can't get lock for resource $resource");
            return undef;
        }
    }

    my $snip_output_file =  $self->snip_output_file;
    my $filtered_snip_output_file = $self->filtered_snip_output_file;
    my $indel_output_file =  $self->indel_output_file;
    my $pileup_output_file = $self->pileup_output_file;

    # Remove the result files from any previous run
    unlink($snip_output_file,$filtered_snip_output_file,$indel_output_file,$pileup_output_file);

    my $retval = system("$maq_pathname cns2snp $assembly_output_file > $snip_output_file");
    unless ($retval == 0) {
        $self->error_message("running maq cns2snp returned non-zero exit code $retval");
        return;
    }

    $retval = system("$maq_pl_pathname SNPfilter $snip_output_file > $filtered_snip_output_file");
    unless ($retval == 0) {
        $self->error_message("running maq.pl SNPfilter returned non-zero exit code $retval");
        return;
    }

    my $accumulated_alignments_file_for_indelsoa = $self->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id);
    unless (-s $accumulated_alignments_file_for_indelsoa ) {
        $self->error_message("Named pipe $accumulated_alignments_file_for_indelsoa was not found.");
        return;
    }
    $retval = system("$maq_pathname indelsoa $ref_seq_file $accumulated_alignments_file_for_indelsoa > $indel_output_file");
    unless ($retval == 0) {
        $self->error_message("running maq indelsoa returned non-zero exit code $retval");
        return;
    }

    # Running pileup requires some parsing of the snip file
    my $tmpfh = File::Temp->new();
    my $snip_fh = IO::File->new($snip_output_file);
    unless ($snip_fh) {
        $self->error_message("Can't open snip output file for reading: $!");
        return;
    }
    while(<$snip_fh>) {
        chomp;
        my ($id, $start, $ref_sequence, $iub_sequence, $quality_score,
            $depth, $avg_hits, $high_quality, $unknown) = split("\t");
        $tmpfh->print("$id\t$start\n");
    }
    $tmpfh->close();
    $snip_fh->close();

    my $accumulated_alignments_file_for_pileup = $self->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id);
    unless (-s $accumulated_alignments_file_for_pileup) {
        $self->error_message("Named pipe $accumulated_alignments_file_for_pileup was not found.");
        return;
    }
    my $pileup_command = sprintf("$maq_pathname pileup -v -l %s %s %s > %s",
                                 $tmpfh->filename,
                                 $ref_seq_file,
                                 $accumulated_alignments_file_for_pileup,
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

    return $self->verify_succesful_completion;
}

sub generate_metrics {
    my $self = shift;

    my @m = $self->metrics;
    for (@m) { $_->delete };

    my $snp_output_file = $self->snip_output_file;
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

sub verify_succesful_completion {
    my $self = shift;

    for my $file ($self->snip_output_file, $self->pileup_output_file) {
        unless (-e $file && -s $file) {
           $self->error_message("file does not exist or is zero size $file");
            return;
        }
    }
    for my $file ($self->filtered_snip_output_file, $self->indel_output_file) {
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

    my $snp_output_file     = $self->snip_output_file;
    my $pileup_output_file  = $self->pileup_output_file;
    my $report_input_file   = $self->genotype_detail_file;

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


1;

