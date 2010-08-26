package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require File::Temp;
require Genome::Model::Tools::FastQual::FastqSetReader;
require Genome::Model::Tools::FastQual::FastqSetWriter;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData',
};

sub bsub_rusage {
    return "-R 'select[type==LINUX64 && tmp>20000] rusage[tmp=20000] span[hosts=1]'"
}

sub execute {
    my $self = shift;

    # Filters
    my $filter = $self->processing_profile->create_read_filter; # undef ok, dies on error

    # Trimers
    my $trimmer = $self->processing_profile->create_read_trimmer; # undef ok, dies on error

    # Readers
    my @fastq_readers = $self->get_fastq_readers
        or return; # error in sub

    # Writer
    my $collated_fastq_file = $self->build->collated_fastq_file;
    unlink $collated_fastq_file if -e $collated_fastq_file;
    my $fastq_writer;
    eval{
        $fastq_writer = Genome::Model::Tools::FastQual::FastqSetWriter->create(
            files => $collated_fastq_file
        );
    };
    unless ( $fastq_writer ) {
        $self->error_message("Can't create writer for collated fastq file ($collated_fastq_file): $@");
        return;
    }

    # Go thru readers, each seq
    my $base_count = 0;
    my $read_count = 0;
    my $base_limit = $self->build->calculate_base_limit_from_coverage;
    READER: for my $fastq_reader ( @fastq_readers ) { 
        FASTQ: while ( my $fastqs = $fastq_reader->next) {
            if ( $trimmer ) {
                $trimmer->trim($fastqs);
            }
            if ( $filter ) {
                next unless $filter->filter($fastqs);
            }

            for my $fastq ( @$fastqs ) {
                my $read_name = $fastq->{id};
                $read_name =~ s/\#.*\/1$/\.b1/; # for ace files
                $read_name =~ s/\#.*\/2$/\.g1/; # for ace files
                $fastq->{id} = $read_name;
                $base_count += length( $fastq->{seq});
		$read_count++;
            }
            my $rv;
            eval{ $rv = $fastq_writer->write($fastqs); };
            unless ( $rv ) {
                $self->error_message("Can't write fastqs to file ($collated_fastq_file): $@");
                return;
            }
            last READER if defined $base_limit and $base_count >= $base_limit;
        }
    }

    $fastq_writer->flush();
    #store number of read processed for assembling
    $self->build->processed_reads_count($read_count);

    # Temp - delete so it doesn't try to save
    $filter->delete if $filter;
    $trimmer->delete if $trimmer;

    unless ( -s $collated_fastq_file ) {
        $self->error_message("Did not write any fastqs for ".$self->build->description.". This probably occurred because the reads did not pass the filter requirements");
        return;
    }

    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.pm $
#$Id: PrepareInstrumentData.pm 45247 2009-03-31 18:33:23Z ebelter $
