package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require File::Temp;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData',
};

sub bsub_rusage {
    return "-R 'select[type==LINUX64 && tmp>20000] rusage[tmp=20000] span[hosts=1]'"
}

sub _tempdir {
    my $self = shift;

    unless ( $self->{_tempdir} ) {
        $self->{_tempdir} = File::Temp::tempdir(CLEANUP => 1 );
        Genome::Utility::FileSystem->validate_existing_directory( $self->{_tempdir} )
            or die;
    }
    
    return $self->{_tempdir};
}

sub execute {
    my $self = shift;
    
    # Filters
    my $filter = $self->processing_profile->create_read_filter; # undef ok, dies on error

    # Trimers
    my $trimmer = $self->processing_profile->create_read_trimmer; # undef ok, dies on error

    # Readers
    my @fastq_readers = $self->_get_fastq_readers
        or return; # error in sub

    # Writer
    my $collated_fastq_file = $self->build->collated_fastq_file;
    unlink $collated_fastq_file if -e $collated_fastq_file;
    my $fastq_writer = Genome::Utility::BioPerl->create_bioseq_writer(
        $collated_fastq_file, 'fastq'
    ); # confess on error

    # Go thru readers, each seq
    my $read_count = 0;
    my $read_limit = $self->build->calculate_read_limit_from_read_coverage;
    FASTQ: while ( 1 ) { 
        my @seqs;
        for my $fastq_reader ( @fastq_readers ) { 
            my $seq = $fastq_reader->next_seq;
	    next unless $seq;
            push @seqs, $seq;
        }
        last FASTQ unless @seqs;
        for my $seq ( @seqs ) {
            $trimmer->trim($seq) if $trimmer;
            if ( $filter ) {
                next unless $filter->filter($seq);
            }
            my $read_name = $seq->id;
            $read_name =~ s/\#.*\/1$/\.b1/; # for ace files
            $read_name =~ s/\#.*\/2$/\.g1/; # for ace files
            $seq->id($read_name);
            my $rv;
            eval{ $rv = $fastq_writer->write_fastq($seq); };
            unless ( $rv ) {
                $self->error_message("Can't write fastq to file ($collated_fastq_file): $@");
                return;
            }

            $read_count++;
            last FASTQ if defined $read_limit and $read_count >= $read_limit;
        }
    }
    $fastq_writer->flush(1);

    unless ( -s $collated_fastq_file ) {
        $self->error_message("Did not write any fastqs for ".$self->build->description.". This probably occurred because the reads did not pass the filter requirements");
        return;
    }

    return 1;
}

sub _get_fastq_readers {
    my $self = shift;

    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->build->description);
        return;
    }

    my $fastq_file_method = '_fastq_files_from_'.$self->processing_profile->sequencing_platform;
    my @fastq_readers;
    for my $inst_data ( $self->build->instrument_data ) {
        my @fastq_files = $self->$fastq_file_method($inst_data)
            or return; # error in sub
        for my $fastq_file ( @fastq_files ) {
            my $fastq_reader = Genome::Utility::BioPerl->create_bioseq_reader(
                $fastq_file, 'fastq'
            ); # confess on error
            push @fastq_readers, $fastq_reader;
        }
    }

    return @fastq_readers;
}

sub _fastq_files_from_solexa {
    my ($self, $inst_data) = @_;

    # zipped fastqs
    my $archive_path = $inst_data->archive_path;
    unless ( -s $archive_path ) {
        $self->error_message(
            "No archive path for instrument data (".$inst_data->id.")"
        );
        return;
    }

    # tar to tempdir
    my $tempdir = $self->_tempdir;
    my $inst_data_tempdir = $tempdir.'/'.$inst_data->id;
    Genome::Utility::FileSystem->create_directory($inst_data_tempdir)
        or die;
    my $tar_cmd = "tar zxf $archive_path -C $inst_data_tempdir";
    Genome::Utility::FileSystem->shellcmd(
        cmd => $tar_cmd,
    ) or Carp::confess "Can't extract archive file $archive_path with command '$tar_cmd'";

    # glob files
    my @fastq_files = glob $inst_data_tempdir .'/*';
    unless ( @fastq_files ) {
        $self->error_message("Extracted archive path ($archive_path), but no fastqs found.");
        return;
    }

    return @fastq_files;
}

sub valid_params {
    return {
        reads_cutoff => {
            is => 'Number',
        },
    };
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.pm $
#$Id: PrepareInstrumentData.pm 45247 2009-03-31 18:33:23Z ebelter $
