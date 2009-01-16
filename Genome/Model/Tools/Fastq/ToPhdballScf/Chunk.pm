package Genome::Model::Tools::Fastq::ToPhdballScf::Chunk;

use strict;
use warnings;

use PP;
use Genome;
use File::Temp;
use File::Basename;
use Bio::SeqIO;
use Bio::Seq::Quality;


class Genome::Model::Tools::Fastq::ToPhdballScf::Chunk {
    is           => 'Genome::Model::Tools::Fastq::ToPhdballScf',
    has_optional => [
        chunk_size => {
            is  => 'Integer',
            doc => 'number of each chunk fastq',
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
    my $self  = shift;

    my $ball_file = $self->ball_file;
    my $ball_dir  = dirname($self->ball_file);
    my $tmp_file  = _get_tmp_file($ball_dir);
    
    my $fq_io  = $self->get_fastq_reader($self->fastq_file);   
    my $out_io = $self->get_fastq_writer($tmp_file);

    my %jobs;
    my @ball_files;

    my $cmd = 'gt fastq to-phdball-scf';
    
    for my $property (qw(time scf_dir base_fix)) {
        if ($self->$property) {
            my $opt_name = $property;
            $opt_name =~ s/_/-/g;
            $cmd .= " --$opt_name";
            $cmd .= ' '.$self->$property unless $property eq 'base_fix';
        }
    }
    
    my $fq_ct = 0;
    my $id_ct = 0;
    my $bl_ct = 0;

    while (my $fq = $fq_io->next_seq) {
        if ($fq_ct == $self->chunk_size) {
            $fq_ct = 0;
            $bl_ct++;
            
            my $ball_chunk_file = $ball_dir.'/phd.ball.'.$bl_ct;
            push @ball_files, $ball_chunk_file;

            my $job = $self->_lsf_job($cmd, $id_ct, $ball_chunk_file, $tmp_file);           
            $jobs{$bl_ct} = $job;
            
            $tmp_file = _get_tmp_file($ball_dir);
            $out_io = $self->get_fastq_writer($tmp_file);
        }
        $out_io->write_fastq($fq);
        $fq_ct++;
        $id_ct++;
    }
    
    $bl_ct++;
    my $ball_chunk_file = $ball_dir.'/phd.ball.'.$bl_ct;
    push @ball_files, $ball_chunk_file;

    my $job = $self->_lsf_job($cmd, $id_ct, $ball_chunk_file, $tmp_file);   
    $jobs{$bl_ct} = $job;
    
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
    
    return 1;
}
            

sub _get_tmp_file {
    my (undef, $tmp_file) = File::Temp::tempfile(
        'FastqChunkXXXXX',
        UNLINK => 1,
        DIR    => shift,
        SUFFIX => '.fq',
    );
    return $tmp_file;
}


sub _lsf_job {
    my ($self, $command, $id_ct, $ball_chunk_file, $tmp_file) = @_;
    
    my $chunk_size = $self->chunk_size;
    my $id_range   = ($id_ct - $chunk_size + 1).'-'.$id_ct;
                  
    $command .= ' --ball-file '.$ball_chunk_file;
    $command .= ' --id-range '.$id_range;
    $command .= ' --fastq-file '.$tmp_file;

    return PP->create(
        pp_type => 'lsf',
        command => $command,
        q       => 'long',
        J       => basename($ball_chunk_file),
    );
}

1;
