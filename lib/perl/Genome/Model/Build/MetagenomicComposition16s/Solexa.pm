package Genome::Model::Build::MetagenomicComposition16s::Solexa;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Model::Build::MetagenomicComposition16s::Solexa {
    is => 'Genome::Model::Build::MetagenomicComposition16s',
};

sub calculate_estimated_kb_usage {
    my $self = shift;

    my $instrument_data_count = $self->instrument_data_count;
    if ( not $instrument_data_count > 0 ) {
        Carp::confess( "No instrument data found for ".$self->description );
    }

    my $kb = $instrument_data_count * 500_000; #TODO .. not sure what best value is

    return ( $kb );
}

#< prepare instrument data >#
sub prepare_instrument_data {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message( "No instrument exists for ".$self->description );
        return;
    }

    my $min_length = $self->processing_profile->amplicon_size;
    my ($attempted, $processed, $reads_attempted, $reads_processed) = (qw/ 0 0 0 /);

    my $fasta_file = $self->processed_fasta_file_for_set_name('');
    my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]);

    for my $inst_data ( @instrument_data ) {
        my @fastq_files = $self->_fastqs_from_solexa( $inst_data );
        my $reader = Genome::Model::Tools::FastQual::FastqReader->create( files => \@fastq_files );

        SEQ: while ( my $fastqs = $reader->read ) {
            for my $fastq ( @$fastqs ) {
                $attempted++;
                $reads_attempted++;
                next SEQ unless length $fastq->{seq} >= $min_length;
                $fastq->{desc} = undef;
                $processed++;
                $reads_processed++;
            }
            $writer->write( $fastqs );
        }
        $self->status_message('DONE PROCESSING: '.$inst_data->id);
    }

    $self->amplicons_attempted($attempted);
    $self->amplicons_processed($processed);
    $self->amplicons_processed_success( $attempted > 0 ?  sprintf('%.2f', $processed / $attempted) : 0 );
    $self->reads_attempted($reads_attempted);
    $self->reads_processed($reads_processed);
    $self->reads_processed_success( $reads_attempted > 0 ?  sprintf('%.2f', $reads_processed / $reads_attempted) : 0 );

    return 1;
}

sub _fastqs_from_solexa {
    my ( $self, $inst_data ) = @_;

    my @fastq_files;

    if ( $inst_data->bam_path ) { #fastq from bam
        $self->error_message("Bam file is zero size or does not exist: ".$inst_data->bam_path ) and return
            if not -s $inst_data->bam_path;
        my $temp_dir = Genome::Sys->create_temp_directory;
        @fastq_files = $inst_data->dump_fastqs_from_bam( directory => $temp_dir );
        $self->status_message( "Got fastq files from bam: ".join( ', ', @fastq_files ) );
    }
    elsif ( $inst_data->archive_path ) { #dump fastqs from archive
        $self->error_message( "Archive file is missing or is zero size: ".$inst_data->archive_path ) and return
            if not -s $inst_data->archive_path;
        my $temp_dir = Genome::Sys->create_temp_directory;
        my $tar_cmd = "tar zxf " . $inst_data->archive_path ." -C $temp_dir";
        $self->status_message( "Running tar: $tar_cmd" );
        unless ( Genome::Sys->shellcmd( cmd => $tar_cmd ) ) {
            $self->error_message( "Failed to dump fastq files from archive path using cmd: $tar_cmd" );
            return;
        }
        @fastq_files = glob $temp_dir .'/*';
        $self->status_message( "Got fastq files from archive path: ".join (', ', @fastq_files) );
    }
    else {
        $self->error_message( "Could not get neither bam_path nor archive path for instrument data: ".$inst_data->id );
        return; #die here
    }

    return @fastq_files;
}

sub _get_writer_for_set_name {
    my ($self, $set_name) = @_;

    unless ( $self->{$set_name} ) {
        my $fasta_file = $self->processed_fasta_file_for_set_name($set_name);
        unlink $fasta_file if -e $fasta_file;
        my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]);
        Carp::confess("Failed to create phred reader for amplicon set ($set_name)") if not $writer;
        $self->{$set_name} = $writer;
    }

    return $self->{$set_name};
}

1;

