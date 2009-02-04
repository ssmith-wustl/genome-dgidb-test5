package Genome::Model::Tools::Fastq::Chunk;

use strict;
use warnings;

use Genome;
use IO::File;
use Bio::SeqIO;
use File::Temp;
use File::Basename;

class Genome::Model::Tools::Fastq::Chunk {
    is  => 'Genome::Model::Tools::Fastq',
    has => [
        chunk_size => {
            is  => 'Integer',
            doc => 'Number of fastq for each chunk',
        },
    ],
    has_optional => [
        chunk_dir => {
            is  => 'String',
            doc => 'Root directory of temp dir to hold chunk fastq files, default is dir of fastq_file',
        },
        show_list => {
            is  => 'boolean',
            doc => 'print file path of fastq chunk file fof to std out',
            default => 0,
        },
    ],
};


sub help_brief {
    'Divide fastq into chunk by chunk_size' 
}


sub help_detail {  
    return <<EOS
    Divide the fastq file of multi-fastq into chunk by given chunk_size. --show-list option will show the file path of chunk file list.
EOS
}


sub create {
    my $class = shift;
    
    my $self = $class->SUPER::create(@_);
    my $root_dir = $self->chunk_dir || dirname $self->fastq_file;
    
    my $chunk_dir = File::Temp::tempdir(
        "FastqChunkDir_XXXXXX", 
        DIR => $root_dir,
    );
    $self->chunk_dir($chunk_dir);

    return $self;
}
        
    
sub execute {
    my $self = shift;
    $self->dump_status_messages($self->show_list);

    my $in_io     = $self->get_fastq_reader($self->fastq_file);
    my $chunk_dir = $self->chunk_dir;

    my $seq_ct  = 0;
    my $file_ct = 0;

    my ($out_io, $chunk_fq_file, @chunk_fq_files);
    
    while (my $seq = $in_io->next_seq) {
        $seq_ct++;
        
        if ($seq_ct > $self->chunk_size || !defined $chunk_fq_file) {
            $seq_ct = 1;
            $file_ct++;
            
            $chunk_fq_file = $chunk_dir."/Chunk$file_ct.fastq";
            $out_io = $self->get_fastq_writer($chunk_fq_file);
            
            push @chunk_fq_files, $chunk_fq_file;
        }
        $out_io->write_fastq($seq);
    }
    
    my $fof_file = $chunk_dir.'/chunk_fastq_file.fof';
    my $fh = IO::File->new(">$fof_file") or
        ($self->error_message("can't write to $fof_file") and return);
    map{$fh->print($_."\n")}@chunk_fq_files;
    $fh->close;

    $self->status_message("List of chunk fastq files:\n$fof_file");        
    return \@chunk_fq_files;
}

1;

