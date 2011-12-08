package Genome::Model::Tools::Sx::Trim::DustAndNRemove;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Sx::Trim::DustAndNRemove {
    is => 'Genome::Model::Tools::Sx',
    has => [
        dust                    => { is => 'Boolean', default_value => 1, 
                                    doc => 'when no-dust is set, skip dusting'
                                    },
        n_removal_threshold     => { is => 'Number', default_value => 0,
                                    doc => 'when non-zero, removes reads which have the specified number of N bases or more' },
        non_n_base_threshold    => { is => 'Number', default_value => 0, 
                                    doc => 'when non-zero, removes reads with less than the specified number of non-N bases'
                                    },
    ],
    doc => 'dust reads and remove reads based on the number of Ns after dusting'
};

sub execute{
    my $self = shift;
    my @inputs = $self->input;
    my @outputs = $self->output;
    
    map {$_=~s/:.*$//}@outputs;#these outputs have :fwd :rev :frag on the end and need to be handled properly
    $self->status_message("DustAndNRemove - inputs: ".join(", ", @inputs)." outputs: ".join(", ", @outputs));

    my $dust = $self->dust;
    my $n_removal_threshold = $self->n_removal_threshold;
    my $non_n_base_threshold = $self->non_n_base_threshold;

    my @intermediate_files;

    if (@inputs == 2){
        if (@outputs == 3){
            $self->_process_unaligned_fastq_pair(@inputs, @outputs);
        }
        else{
            die $self->error_message("Need 3 output files for processing paired-end input");
        }
    }
    elsif(@inputs ==1){
        if (@outputs ==1){
            $self->_process_unaligned_fastq(@inputs, @outputs);
        }
        else{
            die $self->error_message("Need one output file for processing fragment input");
        }
    }
    else{

        die $self->error_message("DustAndNRemove only supports fragment or paired-end input");
    }
    return 1;
}

sub _process_unaligned_fastq_pair {
    my $self = shift;
    my ($forward, $reverse, $forward_out, $reverse_out, $fragment_out) = @_;
    #run dust on forward and reverse
    my $forward_dusted;
    my $reverse_dusted;

    if ($self->dust){
        $self->status_message("Dusting fastq pair $forward, $reverse");
        $forward_dusted = "$forward.DUSTED";
        $reverse_dusted = "$reverse.DUSTED";

        $self->dust_fastq($forward, $forward_dusted);
        $self->dust_fastq($reverse, $reverse_dusted);
    }else{
        $self->status_message("skipping dusting");
        $forward_dusted = $forward;
        $reverse_dusted = $reverse;
    }

    #run pairwise n-removal
    if ($self->n_removal_threshold or $self->non_n_base_threshold){
        $DB::single = 1;
        $self->status_message("running remove-n-pairwise on $forward, $reverse");
        my %params= (forward_fastq => $forward_dusted,
            reverse_fastq => $reverse_dusted,
            forward_n_removed_file => $forward_out,
            reverse_n_removed_file => $reverse_out,
            singleton_n_removed_file => $fragment_out
        );
        if ($self->n_removal_threshold){
            $params{n_removal_threshold}=$self->n_removal_threshold;
        }elsif ($self->non_n_base_threshold){
            $params{non_n_base_threshold}=$self->non_n_base_threshold;
        }
        my $cmd = Genome::Model::Tools::Fastq::RemoveNPairwise->create(
            %params
        );

        unless ($cmd){
            die $self->error_message("couldn't create remove-n-pairwise command for $forward_dusted, $reverse_dusted!");
        }
        my $rv = $cmd->execute;
        unless ($rv){
            die $self->error_message("couldn't create remove-n-pairwise command for $forward_dusted, $reverse_dusted!");
        }
        unless(-e $forward_out && -e $reverse_out && -e $fragment_out){
            die $self->error_message("couldn't find all expected output files! $forward_out, $reverse_out, $fragment_out");
        }
        #clean up, maybe make these temp files
        if ($self->dust){
            #only need to do this if we actually dusted
            unlink $forward_dusted;
            unlink $reverse_dusted;
        }

        #return the 3 processed fastq files
        return ($forward_out, $reverse_out, $fragment_out);
    }else{
        $self->status_message("skipping n-removal");
        Genome::Sys->copy_file($forward_dusted, $forward_out);
        Genome::Sys->copy_file($reverse_dusted, $reverse_out);
        if ($self->dust){
            #only need to do this if we actually dusted
            unlink $forward_dusted;
            unlink $reverse_dusted;
        }
        return ($forward_out, $reverse_out);
    }
}

sub _process_unaligned_fastq {
    my $self = shift;
    my ($fastq_file, $output_path) = @_;

    my $dusted_fastq;
    if ($self->dust){
        $dusted_fastq = "$fastq_file.DUSTED";
        $self->dust_fastq($fastq_file, $dusted_fastq);
    }else{
        $self->status_message("skipping dusting $fastq_file");
        $dusted_fastq = $fastq_file;
    }

    if ($self->n_removal_threshold or $self->non_n_base_threshold){
        $self->status_message("Running n-removal on file $fastq_file");
        my %params=( fastq_file => $dusted_fastq,
            n_removed_file => $output_path
        ); 
        if ($self->n_removal_threshold){
            $params{n_removal_threshold}=$self->n_removal_threshold;
        }elsif ($self->non_n_base_threshold){
            $params{non_n_base_threshold}=$self->non_n_base_threshold;
        }
        my $cmd = Genome::Model::Tools::Fastq::RemoveN->create(%params);
        unless ($cmd){
            die $self->error_message("couldn't create remove-n command for $dusted_fastq");
        }
        my $rv = $cmd->execute;
        unless ($rv){
            die $self->error_message("couldn't execute remove-n command for $dusted_fastq");
        }
    } else {
        $self->status_message("No n-removal params specified, skipping");
        Genome::Sys->copy_file($dusted_fastq, $output_path);
    }
    if ($self->dust){
        unlink $dusted_fastq;
    }
    return $output_path;
}


sub dust_fastq{
    my ($self, $in, $out) = @_;
    my $cmd = Genome::Model::Tools::Fastq::Dust->create(
        fastq_file => $in,
        output_file => $out,
    );
    unless ($cmd){
        die $self->error_message("couldn't create dust command for $in -> $out!");
    }
    my $rv = $cmd->execute;
    unless ($rv){
        die $self->error_message("failed to execute dust command for $in -> $out! rv:$rv");
    }
    unless (-s $out){
        die $self->error_message("expected output file $out doesn't exist or has 0 size!");
    }
    return $out;
}
1;
