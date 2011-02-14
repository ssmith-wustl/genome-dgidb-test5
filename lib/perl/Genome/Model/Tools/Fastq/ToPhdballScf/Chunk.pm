package Genome::Model::Tools::Fastq::ToPhdballScf::Chunk;

use strict;
use warnings;

use PP;
use Genome;
use File::Temp;
use File::Path;
use File::Basename;
use Bio::SeqIO;
use Bio::Seq::Quality;


class Genome::Model::Tools::Fastq::ToPhdballScf::Chunk {
    is  => 'Genome::Model::Tools::Fastq::ToPhdballScf',
    has => [
        chunk_size => {
            is  => 'Integer',
            doc => 'number of each chunk fastq',
        },
	fast_mode => {
	    is => 'Boolean',
	    doc => 'avoid Bio perl slowness',
	    default_value => 1,
	},
    ],
};


sub help_brief {
    "Parallel run fastq-to-phdball-scf as chunk through LSF queue to handle the big fastq file"
}


sub help_detail {                           
    return <<EOS 

EOS
}

sub execute {
    my $self = shift;

    my $ball_file = $self->ball_file;
    my $ball_dir  = dirname($self->ball_file);
    
    my $cmd = 'gmt fastq to-phdball-scf';
    
    for my $property (qw(time scf_dir base_fix solexa_fastq)) {
        if ($self->$property) {
            my $opt_name = $property;
            $opt_name =~ s/_/-/g;
            $cmd .= " --$opt_name";
            
            unless ($property =~ /^(base_fix|solexa_fastq)$/) {
                my $prop_val = $self->$property;
                $prop_val = '"'.$prop_val.'"' if $property eq 'time';
                $cmd .= ' '.$prop_val;
            }
        }
    }
    # add fast_mode to avoid Bio perl slowness 
    my $chunk = Genome::Model::Tools::Fastq::Chunk->create(
        fastq_file => $self->fastq_file,
        chunk_size => $self->chunk_size,
        chunk_dir  => $ball_dir,
	fast_mode  => $self->fast_mode,
    );
    my $fq_chunk_files = $chunk->execute;

    my %jobs;
    my @ball_files;
    my $fq_chunk_dir;
    my $bl_ct = 0;
    
    for my $fq_chunk_file (@$fq_chunk_files) {
        unless (-s $fq_chunk_file) {
            $self->error_message("fastq chunk file: $fq_chunk_file not existing");
            return;
        }
        $fq_chunk_dir = dirname $fq_chunk_file unless $fq_chunk_dir;
        $bl_ct++;
        my $ball_chunk_file = $ball_dir.'/phd.ball.'.$bl_ct;
        push @ball_files, $ball_chunk_file;

        my $job = $self->_lsf_job($cmd, $fq_chunk_file, $ball_chunk_file);           
        $jobs{$bl_ct} = $job;
    }
            
    map{$_->start()}values %jobs;

    my %run;
    map{$run{$_}++}keys %jobs;

    while (%run) {
        sleep 120;
        for my $id (sort{$a<=>$b}keys %run) {
            my $job = $jobs{$id};
                
            if ($job->has_ended) {
                delete $run{$id};
                if ($job->is_successful) {
                    $self->status_message("Job $id done");
                }
                elsif ($job->has_exited) {
                    $self->warning_message("Job $id : ".$job->command." exited");
                }
                else {
                    $self->error_message("Job $id : ".$job->command." ended with neither DONE nor EXIT");
                }
            }
        }
    }
    my $files = join ' ', @ball_files;
    system "cat $files > $ball_file";
    map{unlink $_}@ball_files;
    rmtree $fq_chunk_dir;
    
    return 1;
}
            

sub _lsf_job {
    my ($self, $command, $fq_chunk_file, $ball_chunk_file) = @_;
                      
    $command .= ' --ball-file '.$ball_chunk_file;
    $command .= ' --fastq-file '.$fq_chunk_file;

    return PP->create(
        pp_type => 'lsf',
        command => $command,
        q       => 'long',
        J       => basename($ball_chunk_file),
    );
}

1;
