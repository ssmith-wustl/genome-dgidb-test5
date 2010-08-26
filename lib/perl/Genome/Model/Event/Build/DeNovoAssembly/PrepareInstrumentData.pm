package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
    is_abstract => 1,
};

sub _tempdir {
    my $self = shift;

    unless ( $self->{_tempdir} ) {
        $self->{_tempdir} = File::Temp::tempdir(CLEANUP => 1 );
        Genome::Utility::FileSystem->validate_existing_directory( $self->{_tempdir} )
            or die;
    }
    
    return $self->{_tempdir};
}

#prepare fastq data (velvet, soap)

sub get_fastq_readers {
    my $self = shift;

    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->build->description);
        return;
    }

    my $fastq_file_method = 'fastq_files_from_'.$self->processing_profile->sequencing_platform;
    my @fastq_readers;
    for my $inst_data ( $self->build->instrument_data ) {
        my @fastq_files = $self->$fastq_file_method($inst_data)
            or return; # error in sub
        my $reader;
        eval{
            $reader = Genome::Model::Tools::FastQual::FastqSetReader->create(
                files => \@fastq_files,
            );
        };
        unless ( $reader ) { 
            $self->error_message("Can't create fastq set reader for fastq files (".join(',', @fastq_files)."):$@");
            return;
        }
        push @fastq_readers, $reader;
    }

    return @fastq_readers;
}

sub fastq_files_from_solexa {
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


1;

#$HeadURL$
#$Id$
