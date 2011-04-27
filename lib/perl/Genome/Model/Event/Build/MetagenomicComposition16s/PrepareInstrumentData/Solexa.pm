package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa;

use strict;
use warnings;

use Genome;
use Data::Dumper;

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
    $min_length = 40; #<-- temporarily for testing only .. real length is 200 and test data is only 50 bps

    my $attempted = 0;

    for my $inst_data ( @instrument_data ) {
        my @fastq_files = $self->_fastqs_from_solexa( $inst_data );
        my $reader = Genome::Model::Tools::FastQual::FastqReader->create( files => \@fastq_files );
        SEQ: while ( my $fastqs = $reader->read ) {
            my $seq_match_primer = 0;
            my @fastas_to_write;
            my $set_name = 'none';
            for my $fastq ( @$fastqs ) {
                $attempted++;
                my $seq = $fastq->{seq};
                next SEQ unless length $seq >= $min_length;
                delete $fastq->{desc} if $fastq->{desc};
                REGION: for my $region ( keys %primers ) {
                    for my $primer ( @{$primers{$region}} ) {
                        if ( $seq =~ s/^$primer// ) {
                            #check length again after primer clipped off
                            next SEQ unless length $seq >= $min_length;
                            $fastq->{seq} = $seq;
                            $set_name = $region;
                            $seq_match_primer = 1;
                            last REGION;
                        }
                    }
                }
                push @fastas_to_write, $fastq;
            }
            next SEQ unless $seq_match_primer;
            #print Dumper \@fastas_to_write;
            my $writer = $self->_get_writer_for_set_name( $set_name );
            $writer->write( \@fastas_to_write );
        }
        $self->status_message( 'DONE PROCESSING: '.$inst_data->id );
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
        return; #die here
    }

    return @fastq_files;
}

sub _get_writer_for_set_name {
    my ( $self, $set_name ) = @_;

    if ( not $self->{$set_name} ) {
        my $fasta_file = $self->build->processed_fasta_file_for_set_name($set_name);
        unlink $fasta_file if -e $fasta_file;
        print $fasta_file."\n";
        $self->{$set_name} = Genome::Model::Tools::FastQual::PhredWriter->create( files => [$fasta_file] );
    }

    return $self->{$set_name};
}

1;
