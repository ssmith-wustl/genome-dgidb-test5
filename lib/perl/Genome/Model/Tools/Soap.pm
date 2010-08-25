package Genome::Model::Tools::Soap;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use File::Temp;

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

1;
