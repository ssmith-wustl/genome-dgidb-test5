package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa;

use strict;
use warnings;

use Genome;

require Genome::Model::Tools::FastQual::FastqReader;
require Genome::Model::Tools::FastQual::FastqWriter;

class Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData',
};

sub bsub {
    return "-R 'span[hosts=1] select[type=LINUX64]'";
}

sub execute {
    my $self = shift;

    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message( "No instrument exists for ".$self->build->description );
        return;
    }

    my %primers = $self->build->amplicon_set_names_and_primers;
    my $min_length = $self->processing_profile->amplicon_size;

    my $attempted = 0;

    for my $inst_data ( @instrument_data ) {
        my @fastq_files = $self->fastqs_from_solexa( $inst_data );
        for my $fastq_file ( @fastq_files ) {
            my $reader = Genome::Model::Tools::FastQual::FastqReader->create( file => $fastq_file ); 
            while ( my $fastq = $reader->next ) {
                $attempted++;
                my $set_name = 'none';
                my $seq = $fastq->{seq};
                next unless length $seq >= $min_length;
                REGION: for my $region ( keys %primers ) {
                    for my $primer ( @{$primers{$region}} ) {
                        if ( $seq =~ s/^$primer// ) {
                            $fastq->{seq} = $seq;
                            $set_name = $region;
                            last REGION;
                        }
                    }
                }
                #check length again after primer clipped off
                next unless length $seq >= $min_length;
                delete $fastq->{desc} if $fastq->{desc};
                my $writer = $self->_get_writer_for_set_name( $set_name );
                $writer->write( $fastq );
            }
            $self->status_message( 'DONE PROCESSING: '.$inst_data->id );
        }
    }

    $self->build->amplicons_attempted( $attempted );

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
        return;
    }

    return @fastq_files;
}

sub _get_writer_for_set_name {
    my ( $self, $set_name ) = @_;

    if ( not $self->{$set_name} ) {
        my $fastq_file = $self->build->processed_fasta_file_for_set_name($set_name);
        unlink $fastq_file if -e $fastq_file;
        $self->{$set_name} = Genome::Model::Tools::FastQual::FastqWriter->create( file => $fastq_file );
    }

    return $self->{$set_name};
}

1;
