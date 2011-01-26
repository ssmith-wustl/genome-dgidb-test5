package Genome::Model::Tools::Soap;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use File::Temp;
use File::Basename;

class Genome::Model::Tools::Soap {
    is => 'Command',
    has => [],
};

sub help_detail {
    return <<EOS
    Tools to work with soap aligner and denovo assembler
EOS
}

#methods for soap align

my $SOAP_ALIGN_DEFAULT = '2.20';

my %SOAP_ALIGN_VERSIONS = (
    '2.20' => '/gsc/pkg/bio/soap/SOAPaligner-2.20',
    '2.19' => '/gsc/pkg/bio/soap/SOAPaligner-2.19',
    '2.01' => '/gsc/pkg/bio/soap/SOAPaligner-2.01',
);

sub path_for_soap_align_version {
    my ($class, $version) = @_;
    $version ||= $SOAP_ALIGN_DEFAULT;
    die "soap version: $version is not valid" unless $SOAP_ALIGN_VERSIONS{$version};
    my $path = $SOAP_ALIGN_VERSIONS{$version} . '/soap';
    return $path;
}

sub default_soap_align_version {
    die "default soap version: $SOAP_ALIGN_DEFAULT is not valid" unless $SOAP_ALIGN_VERSIONS{$SOAP_ALIGN_DEFAULT};
    return $SOAP_ALIGN_DEFAULT;
}

sub default_align_version {
    return default_soap_align_version;
}

#methods for soap denovo

sub path_for_soap_denovo_version {
    #my ($self, $version) = @_;
    my $self = shift;
    unless (-s '/gsc/pkg/bio/soap/SOAPdenovo-'.$self->version.'/SOAPdenovo') {
	$self->error_message("Failed to find soap assembler for version: ".$self->verions."\n".
			     "Expected /gsc/pkg/bio/soap/SOAPdenovo-".$self->version.'/SOAPdenovo');
	return;
    }
    return '/gsc/pkg/bio/soap/SOAPdenovo-'.$self->version.'/SOAPdenovo';
}

#create edit_dir

sub create_edit_dir {
    my $self = shift;

    unless ( -d $self->assembly_directory.'/edit_dir' ) {
	Genome::Sys->create_directory( $self->assembly_directory.'/edit_dir' );
    }

    return 1;
}

#derive soap assembly file prefix

sub soap_file_prefix {
    my $self = shift;

    my @files = glob( $self->assembly_directory."/*scafSeq" );

    unless ( @files ) {
	$self->error_message("Did not find any *scafSeq files in assembly directory: ".$self->assembly_directory);
	return;
    }
    
    my ($file_prefix) = $files[0] =~ /^(\S+)\.scafSeq$/;
    $file_prefix = basename ( $file_prefix );

    unless ( $file_prefix ) {
	$self->error_message("Failed to derive file prefix from scafSeq file, expected SRA1234 from name like SRA1234.scafSeq");
	return;
    }

    return $file_prefix;
}

#methods to derive assembly generated files

sub assembly_scaffold_sequence_file {
    my $self = shift;
    
    my @files = glob( $self->assembly_directory."/*scafSeq" ); #glob .. don't know file prefix
    if ( scalar @files != 1 ) {
	$self->error_message("Expected one *scafSeq file in assembly dir but found ".scalar @files);
	return;
    }

    unless ( -s $files[0] ) {
	$self->error_message("Assembly scafSeq file is zero size: ".$files[0]);
	return;
    }

    return $files[0];
}

sub assembly_input_fastq_files {
    my $self = shift;

    my @files = glob( $self->assembly_directory."/*fastq" );
    unless ( @files ) {
	$self->error_message("Failed to find any *fastq files in ".$self->assembly_directory);
	return;
    }
    #there shouldn't be any that are zero size
    for my $fastq ( @files ) {
	unless ( -s $fastq ) {
	    $self->error_message("Input fastq file is zero size: $fastq");
	    return;
	}
    }

    return \@files;
}

sub assembly_config_file {
    my $self = shift;

    my $config_file = $self->assembly_directory.'/config_file';

    unless ( -s $config_file ) {
	$self->error_message("Failed to find config file: $config_file");
	return;
    }

    return $config_file;
}

sub assembly_file_prefix {
    my $self = shift;

    my $scaf_seq_file = $self->assembly_scaffold_sequence_file;

    unless ( $scaf_seq_file ) {
	$self->error_message("Failed to get assembly scafSeq file name to derive assembly file prefix name");
	return;
    }

    my ($path_prefix) = $scaf_seq_file =~ /^(\S+)\.scafSeq$/;
    my $prefix = basename( $path_prefix );

    unless ( $prefix ) {
	$self->error_message("Failed to derive file prefix from file name: ".$scaf_seq_file);
	return;
    }

    return $prefix;
}

#post assemble output file names

sub contigs_bases_file {
    my $self = shift;

    return $self->assembly_directory.'/edit_dir/contigs.bases';
}

sub supercontigs_fasta_file {
    my $self = shift;

    return $self->assembly_directory.'/edit_dir/supercontigs.fasta';
}

sub supercontigs_agp_file {
    my $self = shift;

    return $self->assembly_directory.'/edit_dir/supercontigs.agp';
}

sub stats_file {
    my $self = shift;

    return $self->assembly_directory.'/edit_dir/stats.txt';
}

1;
