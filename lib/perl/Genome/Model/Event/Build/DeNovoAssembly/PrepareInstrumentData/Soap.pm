package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Soap;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require File::Temp;
require Genome::Model::Tools::FastQual::FastqSetReader;
require Genome::Model::Tools::FastQual::FastqSetWriter;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Soap {
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

    # Separate writers for /1 and /2 sequences
    my $end_one_fastq_file = $self->build->end_one_fastq_file;
    unlink $end_one_fastq_file if -s $end_one_fastq_file;
    my $end_two_fastq_file = $self->build->end_two_fastq_file;
    unlink $end_two_fastq_file if -s $end_two_fastq_file;

    my $end_one_fastq_writer;
    eval {
	$end_one_fastq_writer = Genome::Model::Tools::FastQual::FastqWriter->create(
	    file => $end_one_fastq_file,
	    );
    };
    unless ($end_one_fastq_writer) {
	$self->error_message("Can't create writer for fastq file ($end_one_fastq_file): $@");
	return;
    }

    my $end_two_fastq_writer;
    eval {
	$end_two_fastq_writer = Genome::Model::Tools::FastQual::FastqWriter->create(
	    file => $end_two_fastq_file,
	    );
    };
    unless ($end_two_fastq_writer) {
	$self->error_message("Can't create writer for fastq file ($end_two_fastq_file): $@");
	return;
    }

    # Go thru readers, each seq
    my $read_count = 0;
    my $base_count = 0;
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
		#write /1 and /2 seqs separately
		my $rv;
		eval { #write /1
		    $rv = $end_one_fastq_writer->write($fastq);
		} if $read_name =~ /\.b1$/;
		eval { #write /2
		    $rv = $end_two_fastq_writer->write($fastq);
		} if $read_name =~ /\.g1$/;
		unless ($rv) {
		    my $out_fastq = ( $read_name =~ /\.b1$/ ) ? $end_one_fastq_file : $end_two_fastq_file;
		    $self->error_message("Can't write fastq to file ($out_fastq): $@");
		    return;
		}
	    }
	    #TODO - may need some sort of a limit
	    last READER if defined $base_limit and $base_count >= $base_limit;
	}
    }
    #$fastq_writer->flush();
    $end_one_fastq_writer->flush();
    $end_two_fastq_writer->flush();

    #store number of read processed for assembling
    $self->build->processed_reads_count($read_count);

    # Temp - delete so it doesn't try to save
    $filter->delete if $filter;
    $trimmer->delete if $trimmer;

    #TODO - check to make sure end_one and end_two fastas have same # reads?

    if (! -s $end_one_fastq_file and ! -s $end_two_fastq_file) {
	$self->error_message("Did not write any fastqs for ".$self->build->description.". This probably occurred because the reads did not pass the filter requirements");
        return;
    }

    return 1;
}

1;
