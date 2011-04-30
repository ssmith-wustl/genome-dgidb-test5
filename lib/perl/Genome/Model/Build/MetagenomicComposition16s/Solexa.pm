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

#< DIRS >#
sub _sub_dirs {
    return;
}

#< Amplicons >#
sub amplicon_set_names_and_primers { #TODO - these are not real .. modified version of 454 .. for initial testing
    return (
        V1_V3 => [qw/
            CCGCGGCTGC
        /],
        V3_V5 => [qw/
            TCATTTAAGT
            TCATTTGAGT
            TCCTTTAAGT
            TCCTTTGAGT
        /],
        V6_V9 => [qw/
            TACGGCTACC
            TACGGCTACC
            TACGGTTACC
            TACGGTTACC
        /],
    );
}

sub amplicon_set_names {
    my %set_names_and_primers = $_[0]->amplicon_set_names_and_primers;
    return sort keys %set_names_and_primers;
}

#< Clean Up >#
sub clean_up {
    my $self = shift;

    return 1;
}

#< prepare instrument data >#
#processing of solexa data is currently in beginning test phase so there is
#no filtering by primers yet
sub filter_reads_by_primers {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message( "No instrument exists for ".$self->description );
        return;
    }

    my $min_length = $self->processing_profile->amplicon_size;
    my $attempted = 0;

    my $fasta_file = $self->combined_input_fasta_file; #single fasta to of all input reads
    my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]);

    for my $inst_data ( @instrument_data ) {
        my @fastq_files = $self->_fastqs_from_solexa( $inst_data );
        my $reader = Genome::Model::Tools::FastQual::FastqReader->create( files => \@fastq_files );

        SEQ: while ( my $fastqs = $reader->read ) {
            for my $fastq ( @$fastqs ) {
                $attempted++;
                next SEQ unless length $fastq->{seq} >= $min_length;
                delete $fastq->{desc} if $fastq->{desc};
            }
            $writer->write( $fastqs );
        }
        $self->status_message( 'DONE PROCESSING: '.$inst_data->id );
    }

    $self->amplicons_attempted( $attempted );

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

=pod

=head1 Disclaimer

Copyright (C) 2010 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
