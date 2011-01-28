package Genome::Model::Tools::MetagenomicCompositionShotgun::Report;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

use Data::Dumper;
use XML::LibXML;

class Genome::Model::Tools::MetagenomicCompositionShotgun::Report {
    is  => ['Command'],
    has => [
        working_directory => {
            is => 'String',
            is_input => '1',
            doc => 'The working directory where results will be deposited.',
        },
        delete_intermediates => {
            is => 'Integer',
            is_input =>1,
            is_optional =>1,
            default=>0,
        },
        align_final_file => {
            is => 'String',
            is_input => 1,
            doc => 'The working directory where results will be deposited.',
        },
        final_file => {
            is => 'String',
            is_output => 1,
            is_optional =>1,
            doc => 'The working directory where results will be deposited.',
        },

    ],
};


sub help_brief {
    'Generate reports for HMP Metagenomic Pipeline';
}

sub help_detail {
    return <<EOS
    Generate reports.
EOS
}


sub execute {
    my $self = shift;
    $self->dump_status_messages(1);
    $self->dump_error_messages(1);
    $self->dump_warning_messages(1);

    my $now = UR::Time->now;
    $self->status_message(">>>Starting Report execute() at $now"); 
    
    $self->final_file($self->align_final_file);

    my $wd = $self->working_directory;
    my $ath_dir = "$wd/alignments_top_hit";
    my $aligned_merged_sorted = "$ath_dir/aligned_merged_sorted.sam";
    my $a_fh = IO::File->new("< $aligned_merged_sorted");
    my $aligned_count;
    my $last_read = '';
    while (<$a_fh>){
        my ($val) = split (/\t/, $_);
        $aligned_count++ unless $val eq $last_read;
        $last_read = $val;
    }
    my $aligned_read_pairs = $aligned_count;
    my $aligned_reads = $aligned_read_pairs*2;

    my $unaligned_merged = "$ath_dir/unaligned_merged.sam";
    my $unaligned_merged_count = `wc -l $unaligned_merged`;
    my $af_dir = "$wd/alignments_filtered";
    my $low_priority = "$af_dir/low_priority.sam";
    my $low_priority_count = `wc -l $low_priority`;
    my $unaligned_sam = "$af_dir/unaligned.sam";
    my $unaligned_sam_count = `wc -l $unaligned_sam`;
    my $r_dir = "$wd/reports";
    my $final_report = "$r_dir/metrics_summary.txt";
    unlink $final_report if -e $final_report;
    my $fr_ofh = Genome::Sys->open_file_for_writing($final_report);
    $fr_ofh->print("Initial Merged Alignment:\n$aligned_read_pairs aligned read pairs($aligned_reads reads)\n$unaligned_merged_count unaligned_reads\n");
    $fr_ofh->print("Aligned Reads soft clip filtering:\n$low_priority_count reads removed as low priority\n$unaligned_sam_count reads removed as unaligned\n");

    my $reads_per_contig = "$r_dir/reads_per_contig.txt";
    my $rpc_fh = IO::File->new("$reads_per_contig");
    my $total;
    my %kingdom_total;
    while (<$rpc_fh>){
        my ($ref, $reads) = split(/\t/,$_);
        ($ref)=$ref=~/([A-Z]+)_/;
        $total += $reads;
        next unless $ref;
        $kingdom_total{$ref} += $reads;
    }

    $fr_ofh->print("$total reads aligned to metagenomic references. Detail:\n".join("\n", map{"$_ : ".$kingdom_total{$_}}keys %kingdom_total)."\n");

    
    $self->status_message("<<<Ending Report execute() at ".UR::Time->now); 
    return 1;
}
1;
