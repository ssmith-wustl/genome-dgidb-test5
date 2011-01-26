package Genome::Model::Tools::BioSamtools::ErrorRate;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::ErrorRate {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A BAM format file of alignment data'
        },
        output_file => {
            is => 'Text',
            doc => 'A file path to store tab delimited output.',
        },
    ],
};

sub execute {
    my $self = shift;

    my $refcov_bam  = Genome::RefCov::Bam->new(bam_file => $self->bam_file );
    unless ($refcov_bam) {
        die('Failed to load bam file '. $self->bam_file);
    }
    my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
    my $bam  = $refcov_bam->bio_db_bam;
    my $index = $refcov_bam->bio_db_index;
    my $header = $bam->header();
    my $text = $header->text;
    my @lines = split("\n",$text);
    my @rg_lines = grep {$_ =~ /^\@RG/} @lines;
    my %rg_libraries;
    for my $rg_line (@rg_lines) {
        unless ($rg_line =~ /ID\:(\d+)/) { die; }
        my $id = $1;
        unless ($rg_line =~ /LB\:(\S+)/) { die; }
        my $lib = $1;
        $rg_libraries{$id} = $lib;
    }
    my $default_rg_id;
    my @rg_ids = keys %rg_libraries;
    if (scalar(@rg_ids) == 1) {
        $default_rg_id = $rg_ids[0];
    }

    my $targets = $header->n_targets();
    my %read_groups;
    while (my $align = $bam->read1) {
        my $flag = $align->flag;
        my $read_group = $align->aux_get('RG');
        unless ($read_group) {
            if (defined($default_rg_id)) {
                $read_group = $default_rg_id;
            }
        }
        my $type;
        if ($flag & 1) {
            if ($flag & 64)  {
                $type = 'read_1';
            } else {
                $type = 'read_2';
            }
        } else {
            $type = 'fragment';
        }
        unless ($flag & 4) {
            my $match_descriptor = $align->aux_get('MD');
            my $x_descriptor = $align->aux_get('XD');
            unless ($match_descriptor) {
                $match_descriptor = $align->aux_get('XD');
            }
            my @match_fields = split(/[^0-9]+/,$match_descriptor);
            #sum
            for my $matches (@match_fields) {
                if ($matches =~ /^\s*$/) { next; }
                $read_groups{$read_group}{$type}{matches} += $matches;
            }
            #character count minus ^
            my @mismatch_fields = split(/[0-9]+/,$match_descriptor);
            for my $mismatch_field (@mismatch_fields) {
                $mismatch_field =~ s/\^//g;
                $read_groups{$read_group}{$type}{mismatches} += length($mismatch_field);
            }
            #print $match_descriptor ."\t". $match_sum ."\t". $mismatch_sum ."\n";
        } else {
            $read_groups{$read_group}{$type}{unaligned} += $align->l_qseq;
        }
    }
    print $output_fh "LIBRARY\tREAD_GROUP\tREAD_TYPE\tUNALIGNED\tALIGNED\tPC_ALIGNED\tMISMATCHES\tMATCHES\tERROR\n";
    for my $read_group (sort keys %read_groups) {
        for my $read_group_type (sort keys %{$read_groups{$read_group}}) {
            my $read_group_type_matches = $read_groups{$read_group}{$read_group_type}{matches};
            my $read_group_type_mismatches = $read_groups{$read_group}{$read_group_type}{mismatches};
            my $read_group_type_unaligned = $read_groups{$read_group}{$read_group_type}{unaligned};
            my $read_group_type_aligned = $read_group_type_matches + $read_group_type_mismatches;
            my $read_group_type_total = $read_group_type_aligned + $read_group_type_unaligned;
            my $read_group_type_align_rate = sprintf("%.02f",(($read_group_type_aligned / $read_group_type_total ) * 100));
            my $read_group_type_error_rate = sprintf("%.02f",(($read_group_type_mismatches / $read_group_type_aligned ) * 100));
            print $output_fh $rg_libraries{$read_group} ."\t". $read_group ."\t". $read_group_type ."\t".$read_group_type_unaligned ."\t". $read_group_type_aligned ."\t". $read_group_type_align_rate
                ."\t". $read_group_type_mismatches ."\t". $read_group_type_matches ."\t". $read_group_type_error_rate ."%\n";
        }
    }
    $output_fh->close;
    return 1;
}

1;
