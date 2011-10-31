package Genome::Model::Tools::Sam::Pileup;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Sam::Pileup {
    is  => 'Genome::Model::Tools::Sam',
    has_input => [
        bam_file => {
            is  => 'Text',
            doc => 'Input BAM File',
        },
        output_file => {
            is => 'Text',
            is_output => 1,
            doc => 'Output Pileup File',
        },
        reference_sequence_path => {
            is => 'Text',
            doc => 'Path to the reference fa or fasta',
        },
        use_bgzip => {
            is => 'Boolean',
            doc => 'Set this to bgzip the output of pileup',
        },
    ],
    has_optional_input => [
        region_file => {
            is => 'Text',
            doc => "limit calls to this region",
        },
    ],
};

sub execute {
    my $self = shift;
    my $bam = $self->bam_file;
    my $output_file = $self->output_file;

    #check accessibility of inputs
    unless (-s $bam) {
        die $self->error_message("Could not locate BAM or BAM had no size: ".$bam);
    }
    my $refseq_path = $self->reference_sequence_path;
    unless(-s $refseq_path){
        die $self->error_message("Could not locate Reference Sequence at: ".$refseq_path);
    }

    #check to see if the region file is gzipped, if so, pipe zcat output to the -l
    my $rf = $self->region_file;
    my $region_file = undef;
    if(defined($self->region_file)){
        if($rf =~ m/.bed.gz$/){
            $region_file = "-l <(zcat ".$rf.") ";
        }elsif (defined($rf)){
            $region_file = "-l ".$rf;
        }
    }

    #if bgzip is set, push the output through bgzip then to disk
    my $out;
    if($self->use_bgzip){
        $out = "| bgzip -c > ".$output_file."\"";
    } else {
        $out = "> ".$output_file."\"";
    }

    #put the command components together
    my $cmd = "bash -c \"".$self->path_for_samtools_version($self->use_version)." pileup -c -f ".$self->reference_sequence_path." ".$bam." ".$region_file." ".$out;

    my $result = Genome::Sys->shellcmd( cmd => $cmd);
    unless($result){
        die $self->error_message("failed to execute cmd: ".$cmd);
    }

    return 1;
}


1;
