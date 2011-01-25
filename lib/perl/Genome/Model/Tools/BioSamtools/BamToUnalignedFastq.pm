package Genome::Model::Tools::BioSamtools::BamToUnalignedFastq;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::BamToUnalignedFastq {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A BAM format file of alignment data.'
        },
        output_directory => {
            is => 'Text',
            doc => 'A directory to output s_*_*_sequence.txt files.  Two files for unmapped pairs and one file for unmapped fragments or unmapped mates whose mate-pair is mapped.',
        },
    ],
};

sub execute {
    my $self = shift;

    unless (-d $self->output_directory) {
        unless (Genome::Sys->create_directory($self->output_directory)) {
            die('Failed to create output directory '. $self->output_directory);
        }
    }
    my $refcov_bam = Genome::RefCov::Bam->new(bam_file => $self->bam_file );

    # create low level bam object
    my $bam  = $refcov_bam->bio_db_bam;
    my $header = $bam->header();

    # Number of reference sequences
    my $targets = $header->n_targets();

    # The reference sequence names in an array ref with indexed positions
    my $target_names = $header->target_name();

    # at the low level API the seq_id/target_name is meaningless
    # cache the target_names in a hash by actual reference sequence name
    # then we can look up the target index on the fly
    my %target_name_index;
    my $i = 0;
    for my $target_name (@{ $target_names }) {
        $target_name_index{$target_name} = $i++;
    }

    # Make sure our index is not off
    unless ($targets == $i) {
        die 'Expected '. $targets .' targets but counted '. $i .' indices';
    }

    #We don't want the index since the BAM is sorted by name
    #my $index = $refcov_bam->bio_db_index;

    #Parse through header and create filehandles for all lanes
    my $text = $header->text;
    my @lines = split("\n",$text);
    my %fhs;
    for my $line (@lines) {
        if ($line =~ /^\@RG/){
            unless ($line =~ /^\@RG\s+ID:(\d+).+PU:\S+\.(\d+).+DS:(paired end|fragment)/) {
                die('Failed to match line '. $line .' with regex!');
            }
            my $instrument_data_id = $1;
            my $lane = $2;
            my $run_type = $3;
            my $instrument_data_directory = $self->output_directory .'/'. $instrument_data_id;
            unless (Genome::Sys->create_directory($instrument_data_directory)) {
                die('Failed to create instrument data directory '. $instrument_data_directory);
            }
            my $fragment_file = $instrument_data_directory .'/s_'. $lane .'_sequence.txt';
            my $fragment_fh = Genome::Sys->open_file_for_writing($fragment_file);
            unless ($fragment_fh) {
                die('Failed to create fragment filehandle '. $fragment_file);
            }
            $fhs{$instrument_data_id}{'fragment'} = $fragment_fh;
            if ($run_type eq 'paired end') {
                for my $end (1 .. 2) {
                    my $end_file = $instrument_data_directory .'/s_'. $lane .'_'.$end .'_sequence.txt';
                    my $end_fh = Genome::Sys->open_file_for_writing($end_file);
                    unless ($end_fh) {
                        die('Failed to create read end '. $end .' filehandle '. $end_file);
                    }
                    my $key = 'read_'. $end;
                    $fhs{$instrument_data_id}{$key} = $end_fh;
                }
            }
        }
    }

    my %read_pairs;
    while (my $align = $bam->read1()) {
        my $flag = $align->flag;
        if ($flag & 1) {
            my $type;
            if ($flag & 64)  {
                $type = 'read_1';
            } elsif ($flag & 128) {
                $type = 'read_2';
            } else {
                die('Read pair info lost for alignment of read '. $align->qname .' from BAM file '. $self->bam_file);
            }
            if ($flag & 4) {
                if ($flag & 8) {
                    # Treat as Paired-End
                    print_align_to_fh($align,\%fhs,$type);
                } else {
                    # Treat as Fragment
                    print_align_to_fh($align,\%fhs,'fragment');
                }
            }
        } else {
            # Fragment Read
            if ($flag & 4) {
                #Unmapped Fragment Read
                print_align_to_fh($align,\%fhs,'fragment');
            }
        }
    }
    return 1;
}


sub print_align_to_fh {
    my $align = shift;
    my $fhs = shift;
    my $type = shift;
    
    my $instrument_data_id = $align->aux_get('RG');
    my $fh = $fhs->{$instrument_data_id}->{$type};
    unless ($fh) {
        die('Failed to get back fragment filehandle using instrument data id '. $instrument_data_id .' and read type '. $type);
    }
    my $name = $align->qname;
    # TODO: verify orientation with original fastq
    my $seq = $align->qseq;
    # TODO: verify orientation and quality conversion with original fastq
    my @quals = $align->qscore;
    my $qual = '';
    for my $phred_value (@quals) {
        my $ill_value = chr($phred_value + 64);
        $qual .= $ill_value;
    }
    print $fh '@' ."$name\n$seq\n+\n$qual\n";
}


1;
