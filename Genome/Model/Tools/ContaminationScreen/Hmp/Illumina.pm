package Genome::Model::Tools::ContaminationScreen::Hmp::Illumina;

use strict;
use warnings;

use Genome;
use Command;
use Workflow::Simple;
use Data::Dumper;
use File::Basename;

UR::Object::Type->define(
    class_name  => __PACKAGE__,
    is => 'Genome::Model::Tools::ContaminationScreen::Hmp',
    has         => [
                        dir     => {
                           doc => 'directory of inputs',
                           is => 'String',
		           is_optional => 1,
		           default => $ENV{"PWD"},

                        },
                        fastq1=> {
                           doc => 'first file of reads to be checked for contamination',
                           is => 'String',
                           is_input => 1,
                        },
                        fastq2=> {
                           doc => 'first file of reads to be checked for contamination',
                           is => 'String',
                           is_input => 1,
                        },
                        edit_distance =>  {
                           doc => 'maximum edit distance',
                           is => 'Number',
                           is_input => 1,
                           is_optional => 1,
                           default => 15,
                        },
                        n_cutoff =>  {
                           doc => 'cutoff for n-removal (0 to override)',
                           is => 'Number',
                           is_input => 1,
                           is_optional => 1,
                           default => 0,
                        },
                        save_screened_reads =>  {
                           doc => 'save reads screened during post-dust n-removal',
                           is => 'Boolean',
                           is_input => 1,
                           is_optional => 1,
                           default => 1,
                        },
                        mismatch_cutoff =>  {
                           doc => 'cutoff for post-dust n-removal (0 to override)',
                           is => 'Number',
                           is_input => 1,
                           is_optional => 1,
                           default => 10,
                        },

                    ],
);

sub help_brief
{
    "Run illumina human contamination screening";
}

sub help_synopsis
{
    return << "EOS"
    genome-model tools illumina...
EOS
}

sub help_detail
{
    return << "EOS"
    Runs the illumina hcs pipeline.  Takes a directory for output, and two fastq files.
EOS
}

sub create 
{
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return $self;
}

sub execute {
    my $self = shift;

    my $dir = $self->dir;
    my ($fastq1, $fastq2) = ($self->fastq1, $self->fastq2);
    my $base1 = basename $fastq1;
    my $base2 = basename $fastq2;
    my $cutoff = $self->n_cutoff;
    my ($primer_trim_file1, $primer_trim_file2)  = ($dir . "/$base1.TRIMMED1.fasta", $dir . "/$base2.TRIMMED2.fasta");
    my ($aligner_output_file1, $aligner_output_file2)  = ($dir . "/$base1.ALIGNER_OUTPUT1.sai", $dir . "/$base2.ALIGNER_OUTPUT2.sai");
    my ($unaligned_reads_file1, $unaligned_reads_file2)  = ($dir . "/$base1.UNALIGNED1.sam", $dir . "/$base2.UNALIGNED2.sam");
    my ($alignment_file1, $alignment_file2) = ($dir . "/$base1.ALIGNED1.sam",  $dir . "/$base2.ALIGNED2.sam"); 
    my ($deduplicated_file1, $deduplicated_file2) = ($dir . "/$base1.DEDUP1.sam", $dir . "/$base2.DEDUP2.sam");
    my $ref_seq_file = "/gscmnt/sata156/research/mmitreva/databases/human_build36/Homo_sapiens.NCBI36.45.dna.aml.plus5.8s15s28s.fna";
    my $align_options = '-t 4 -n ' . $self->edit_distance;
    my ($n_removed_file1, $n_removed_file2)  =  ($dir . "/$base1.N_REMOVED1.fastq", $dir . "/$base2.N_REMOVED2.fastq");
    my ($paired_end_file1,  $paired_end_file2) = ($dir . "/$base1.PAIRED_REMOVED1.sam", $dir . "/$base2.PAIRED_REMOVED2.sam");
    my ($resurrected_file1, $resurrected_file2) = ($dir . "/$base1.RESURRECTED1.sam", $dir . "/$base2.RESURRECTED2.sam");
    my $synch_output  = ".SYNCH";
    my ($prefix1, $prefix2) = ($dir . "/$base1", $dir . "/$base2");
    my ($fasta_file1, $fasta_file2) = ("$dir/$base1.SYNCH.fasta", "$dir/$base2.SYNCH.fasta");
    my $save_screened_reads = $self->save_screened_reads;
    my $mismatch_cutoff = $self->mismatch_cutoff;
    my ($mismatch_removed_file1, $mismatch_removed_file2) = ("$dir/$base1.MISMATCH_REMOVED.fasta", "$dir/$base2.MISMATCH_REMOVED.fasta");
    my $xml_file = dirname ($self->__meta__->module_path()) . "/illumina_workflow.xml";
    my $output = run_workflow_lsf(
                              $xml_file,
                              'fastq_1'                 => $fastq1,
                              'fastq_2'                 => $fastq2,
                              'primer_trim_file1'       => $primer_trim_file1,
                              'primer_trim_file2'       => $primer_trim_file2,
                              'cutoff'                  => $cutoff,
                              'align_options_1'         => $align_options,
                              'align_options_2'         => $align_options,
                              'alignment_file_1'        => $alignment_file1, 
                              'alignment_file_2'        => $alignment_file2, 
                              'aligner_output_file_1'   => $aligner_output_file1,
                              'aligner_output_file_2'   => $aligner_output_file2,
                              'unaligned_reads_file_1'  => $unaligned_reads_file1,
                              'unaligned_reads_file_2'  => $unaligned_reads_file2,
                              'n_removed_file_1'        => $n_removed_file1,
                              'n_removed_file_2'        => $n_removed_file2,
                              'paired_end_file_1'       => $paired_end_file1,
                              'paired_end_file_2'       => $paired_end_file2,
                              'deduplicated_file_1'     => $deduplicated_file1,
                              'deduplicated_file_2'     => $deduplicated_file2,
                              'ref_seq_file'            => $ref_seq_file,
                              'resurrected_file_1'      => $resurrected_file1,
                              'resurrected_file_2'      => $resurrected_file2, 
                              'prefix1'                 => $prefix1,
                              'prefix2'                 => $prefix2,
                              'fasta_file1'             => $fasta_file1,
                              'fasta_file2'             => $fasta_file2,
                              'output'                  => $synch_output,
                              'save_screened_reads'     => $save_screened_reads,
                              'mismatch_removed_file1'  => $mismatch_removed_file1,
                              'mismatch_removed_file2'  => $mismatch_removed_file2,
                              'mismatch_cutoff'         => $mismatch_cutoff,
                          );

print Data::Dumper->new([$output,\@Workflow::Simple::ERROR])->Dump;
    my $mail_dest = $ENV{USER}.'@genome.wustl.edu';
    my $sender = Mail::Sender->new({
        smtp => 'gscsmtp.wustl.edu',
        from => 'illumina-bwa@genome.wustl.edu',
        replyto => 'donotreply@watson.wustl.edu',
    });
    $sender->MailMsg({
        to => $mail_dest,
        subject => "Illumina Bwa Test",
        msg     => "Illumina Bwa Test run with\n\n" .
                              "input 1:\t$fastq1\n" .
                              "input 2:\t$fastq2\n" .
                              "primer_trim_file 1:\t$primer_trim_file1\n" .
                              "primer_trim_file 2:\t$primer_trim_file2\n" .
                              "n cutoff:\t$cutoff\n" .
                              "n_removed_file 1:\t$n_removed_file1\n" .
                              "n_removed_file 2:\t$n_removed_file2\n" .
                              "align_options 1:\t$align_options\n" .
                              "align_options 2:\t$align_options\n" .
                              "aligner_output_file 1:\t$aligner_output_file1\n" .
                              "aligner_output_file 2:\t$aligner_output_file2\n" .
                              "alignment_file 1:\t$alignment_file1\n" . 
                              "alignment_file 2:\t$alignment_file2\n" . 
                              "ref_seq_file\t$ref_seq_file\n" .
                              "unaligned_reads_file 1:\t$unaligned_reads_file1\n" .
                              "unaligned_reads_file 2:\t$unaligned_reads_file2\n" .
                              "deduplicated_file 1:\t$deduplicated_file1\n" .
                              "deduplicated_file 2:\t$deduplicated_file2\n" .
                              "resurrected_file1:\t$resurrected_file1\n" .
                              "resurrected_file2:\t$resurrected_file2\n" . 
                              "prefix1:\t$prefix1\n" .
                              "prefix2:\t$prefix2\n" .
                              "fasta file 1:\t$fasta_file1\n" .
                              "fasta file 2:\t$fasta_file2\n" .
                              "output:\t$synch_output\n" .
                              "mismatch_cutoff:\t$mismatch_cutoff\n" ,
    });

    return 1;
}
