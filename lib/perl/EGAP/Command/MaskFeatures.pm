package EGAP::Command::MaskFeatures;

use strict;
use warnings;

use EGAP;

use Bio::SeqIO;
use Bio::SeqFeature::Generic;

use Carp qw(confess);
use File::Path qw(make_path);
use File::Basename qw(fileparse);

class EGAP::Command::MaskFeatures {
    is => 'EGAP::Command',
    has => [
        output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'Masked fasta file is placed in this directory',
        },
        fasta_file => { 
            is  => 'Path',
            is_input => 1,
            doc => 'single fasta file', 
        },
        bio_seq_feature => { 
            is  => 'ARRAY',
            is_input => 1,
            doc => 'array of Bio::Seq::Feature', 
        },
    ],
    has_optional => [
        masked_fasta_file => {
            is => 'Path',
            is_output => 1,
            doc => 'single masked fasta file',
        },
    ],
};

sub help_brief {
    return "Masks out sequence for predicted features";
}

sub help_synopsis {
    return <<EOS
Takes a fasta and a list of predictions made using the sequence in the fasta.
Any sequence held within the existing predictions is replaced with Ns.
EOS
}

sub help_detail {
    return <<EOS
Takes a fasta and a list of predictions made using the sequence in the fasta.
Any sequence held within the existing predictions is replaced with Ns.
EOS
}

sub execute {
    my ($self) = @_;

    my $output_dir = $self->output_directory;
    unless (-d $output_dir) {
        my $mkdir_rv = make_path($output_dir);
        confess "Couldn't created output directory at $output_dir!" unless $mkdir_rv;
    }

    my ($fasta_file_name, $fasta_directory, $fasta_suffix) = fileparse($self->fasta_file);
    my $masked_path = "$output_dir/$fasta_file_name" . "_masked.fa";
    
    my $seq_in = Bio::SeqIO->new(
        -format => 'Fasta', 
        -file => $self->fasta_file()
    );
    my $seq_out = Bio::SeqIO->new(
        -format => 'Fasta', 
        -file => ">$masked_path",
    );
    
    # TODO Might need to add support for multi-fasta files
    my $seq = $seq_in->next_seq();
    my $display_id = $seq->display_id(); 
    my $seq_string = $seq->seq();
   
    for my $feature (@{$self->bio_seq_feature()}) {
        my $seq_id = $feature->seq_id();
        my $length = $feature->length();
        my $start  = $feature->start();
        my $end    = $feature->end();
        
        unless ($display_id eq $seq_id) {
            confess "Feature with sequence ID $seq_id doesn't match expected ID of $display_id!";
        }

        for my $coord ($start, $end) {
            if ($coord < 1) {
                $coord = 1;
            }
            if ($coord > $seq->length()) {
                $coord = $seq->length();
            }
        }
        
        unless ($start <= $end) { 
            ($start, $end) = ($end, $start); 
        }
       
        $length = ($end - $start) + 1;
        
        # Any sequence within the predicted feature is replaced with an N here
        substr($seq_string, $start - 1, $length, 'N' x $length);
    }

    my $masked_seq = Bio::Seq->new(
        -display_id => $display_id, 
        -seq => $seq_string
    );

    $seq_out->write_seq($masked_seq);
    $self->masked_fasta_file($masked_path);
    return 1;
}

1;
