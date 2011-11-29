package Genome::Model::Tools::BioSamtools::ErrorRatePileup;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::ErrorRatePileup {
    is => ['Genome::Model::Tools::BioSamtools'],
    has => [
        bam_file => {},
        reference_fasta => {},
    ],
    has_optional => [
        output_file => {},
    ],
};

sub execute {
    my $self = shift;

    my $fai = Bio::DB::Sam::Fai->load($self->reference_fasta);
    unless ($fai) {
        die('Failed to load fai for: '. $self->reference_fasta);
    }

    my $bam = Bio::DB::Bam->open($self->bam_file);
    unless ($bam) {
        die('Failed to load BAM file: '. $self->bam_file);
    }

    my $index  = Bio::DB::Bam->index($self->bam_file);
    unless ($index) {
        die('Failed to load BAM index for: '. $self->bam_file);
    }

    my $header = $bam->header;
    my $tid_names = $header->target_name;
    my $tid_lengths = $header->target_len;

    my %count;
    my %del_pileups;
    my $callback = sub {
        my ($tid,$pos,$pileups,$callback_data) = @_;
        my $chr = $tid_names->[$tid];
        my $ref_base = $fai->fetch($chr .':'. ($pos+1) .'-'. ($pos+1) );
        for my $pileup (@$pileups) {
            my $b = $pileup->alignment;
            my $qname = $b->qname;

            my $qpos = $pileup->qpos;
            $count{total}->[$qpos]++;

            my $qbase = substr($b->qseq,$qpos,1);

            my $indel = $pileup->indel;
            if ($indel) {
                my $indel_size = abs($indel);
                if ($indel > 0) {
                    for (1 .. $indel_size) {
                        my $ipos = ($qpos + $_);
                        $count{insertion}->[$ipos]++;
                        $count{total}->[$ipos]++;
                    }
                } else {
                    $count{deletion}->[$qpos] += $indel_size;
                    for (1 .. $indel_size) {
                        # This is relative to the reference position
                        my $dpos = ($pos + $_);
                        $del_pileups{$qname}{$dpos} = 1;
                    }
                }
            } elsif ($del_pileups{$qname}{$pos}) {
                my $del_pileup = delete($del_pileups{$qname}{$pos});
                $count{total}->[$qpos]--;
                #$DB::single = 1;
                #print $pos ."\t". $ref_base ."\t". $qname ."\t". $del_pileup ."\t". $del_pileup ."\t". $pileup->qpos ."\t". $qbase ."\t". $pileup->indel ."\n";
                next;
            }
            if ($qbase =~ /[nN]/) {
                $count{ambiguous}->[$qpos]++;
            } elsif ($ref_base ne $qbase) {
                $count{mismatch}->[$qpos]++;
            } else {
                $count{match}->[$qpos]++;
            }
        }
    };
    for (my $i = 0; $i < scalar(@{$tid_lengths}); $i++) {
        my $end = $tid_lengths->[$i];
        $index->pileup($bam,$i,'0',$end,$callback);
    }
    my @headers = qw/position total match error error_rate mismatch mismatch_rate ambiguous ambiguous_rate insertion insertion_rate deletion deletion_rate/;
    my $writer = Genome::Utility::IO::SeparatedValueWriter->create(
        separator => "\t",
        headers => \@headers,
        output => $self->output_file,
    );
    unless ($writer) {
        die('Failed to create output writer!');
    }
    my @positions = @{$count{total}};
    my $sum_total;
    my $sum_match;
    my $sum_mismatch;
    my $sum_ambiguous;
    my $sum_insertion;
    my $sum_deletion;
    my $sum_error;
    for (my $i = 0; $i < scalar(@positions); $i++) {
        my $position_count = $positions[$i];
        if (!$position_count) {
            my %data = (
                position => $i,
                total => 0,
                match => 0,
                error => 0,
                error_rate => 0,
                mismatch => 0,
                mismatch_rate => 0,
                ambiguous => 0,
                ambiguous_rate => 0,
                insertion => 0,
                insertion_rate => 0,
                deletion => 0,
                deletion_rate => 0,
            );
            $writer->write_one(\%data);
            next;
        }
        my $match = $count{match}->[$i] || 0;
        my $mismatch = $count{mismatch}->[$i] || 0;
        my $ambiguous = $count{ambiguous}->[$i] || 0;
        my $insertion = $count{insertion}->[$i] || 0;
        my $deletion = $count{deletion}->[$i] || 0;

        my $total = $match + $mismatch + $ambiguous + $insertion + $deletion;
        my $error = $mismatch + $ambiguous + $insertion + $deletion;
        my $error_rate = $error / $total;
        my $mismatch_rate = $mismatch / $total;
        my $ambiguous_rate = $ambiguous / $total;
        my $insertion_rate = $insertion / $total;
        my $deletion_rate = $deletion / $total;
        my %data = (
            position => $i,
            total => $total,
            match => $match,
            error => $error,
            error_rate => $error_rate,
            mismatch => $mismatch,
            mismatch_rate => $mismatch_rate,
            ambiguous => $ambiguous,
            ambiguous_rate => $ambiguous_rate,
            insertion => $insertion,
            insertion_rate => $insertion_rate,
            deletion => $deletion,
            deletion_rate => $deletion_rate,
        );
        $writer->write_one(\%data);
        $sum_total += $total;
        $sum_match += $match;
        $sum_mismatch += $mismatch;
        $sum_ambiguous += $ambiguous;
        $sum_insertion += $insertion;
        $sum_deletion += $deletion;
        $sum_error += $error;
    }
    my $error_rate = $sum_error / $sum_total;
    my $mismatch_rate = $sum_mismatch / $sum_total;
    my $ambiguous_rate = $sum_ambiguous / $sum_total;
    my $insertion_rate = $sum_insertion / $sum_total;
    my $deletion_rate = $sum_deletion / $sum_total;
    my %data = (
        position => 'SUM',
        total => $sum_total,
        match => $sum_match,
        error => $sum_error,
        error_rate => $error_rate,
        mismatch => $sum_mismatch,
        mismatch_rate => $mismatch_rate,
        ambiguous => $sum_ambiguous,
        ambiguous_rate => $ambiguous_rate,
        insertion => $sum_insertion,
        insertion_rate => $insertion_rate,
        deletion => $sum_deletion,
        deletion_rate => $deletion_rate,
    );
    $writer->write_one(\%data);
    return 1;
}
