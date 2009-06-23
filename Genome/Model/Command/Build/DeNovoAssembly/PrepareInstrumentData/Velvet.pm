package Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData::Velvet;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Bio::SeqIO::fastq;

class Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData::Velvet {
    is => 'Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData',
};

sub execute {
    my $self = shift;
    my $data_type = $self->model->processing_profile->sequencing_platform;
    my $method = '_prepare_'.$data_type.'_data';
    unless ($self->can($method)) {
	$self->error_message("Invalid sequencing platform name: $data_type");
	return;
    }

    unless ($self->$method()) {
	$self->error_message("Failed to execute prepare instrument data");
	return;
    }

    return 1;
}

sub _prepare_solexa_data {
    my $self = shift;

    my @instrument_data = $self->model->instrument_data;
    unless (@instrument_data) {
	$self->error_message("");
	return;
    }

    if (@instrument_data > 1) {
	$self->error_message("");
	return;
    }

    my @fastqs = $instrument_data[0]->fastq_filenames;

    if (@fastqs > 2) {
	$self->error_message("");
	return;
    }

    my $fq1 = Bio::SeqIO::fastq->new(-file => $fastqs[0]);
    my $fq2 = Bio::SeqIO::fastq->new(-file => $fastqs[1]);
    my $fq_out = Bio::SeqIO::fastq->new(-file => '>'.$self->build->velvet_fastq_file);

    my $limit = $self->get_read_limit_count();
    my $cnt = 0;

    while ( my $seq1 = $fq1->next_seq ) {
	last if ++$cnt > $limit;
	my $seq2 = $fq2->next_seq;
	unless ( $seq2 ) {
	    $self->error_message("Odd number of fastqs in files: ".join(', ', @fastqs));
	    return;
	}
	my $pcap_id = $self->_convert_to_pcap_id($seq1->id);
	$seq1->id($pcap_id);
	$fq_out->write_fastq($seq1);

	$pcap_id = $self->_convert_to_pcap_id($seq2->id);
	$seq2->id($pcap_id);
	$fq_out->write_fastq($seq2);
    }

    return 1;
}

sub _convert_to_pcap_id {
    my ($self, $read_name) = @_;
    $read_name =~ s/\#0\/1/\.b1/;
    $read_name =~ s/\#0\/2/\.g1/;
    return $read_name;
}

sub get_read_limit_count {
    my $self = shift;
    my $string = $self->model->processing_profile->{_prepare_instrument_data_params};
    my ($limit) = $string =~ /cutoff\s+(\d+)/;
    return $limit;
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
