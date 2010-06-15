package Genome::Model::Tools::Soap;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use File::Temp;

my $SOAP_DEFAULT = '2.20';

class Genome::Model::Tools::Soap {
    is => ['Command'],
    has_optional => [
        use_version => {
                    is    => 'string',
                    doc   => 'version of Soap application to use',
                    default_value => $SOAP_DEFAULT
                },
        _tmp_dir => {
                    is => 'string',
                    doc => 'a temporary directory for storing files',
                },
    ],
    doc => 'tools to work with the SOAP aliger'
};

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS
    Soap2 aligner system.
EOS
}

my %SOAP_VERSIONS = (
    '2.20' => '/gsc/pkg/bio/soap/SOAPaligner-2.20',
    '2.19' => '/gsc/pkg/bio/soap/SOAPaligner-2.19',
    '2.01' => '/gsc/pkg/bio/soap/SOAPaligner-2.01',
);

sub path_for_soap_version {
    my ($class, $version) = @_;
    $version ||= $SOAP_DEFAULT;
    die "soap version: $version is not valid" unless $SOAP_VERSIONS{$version};
    my $path = $SOAP_VERSIONS{$version} . '/soap';
    return $path;
}

sub default_soap_version {
    die "default soap version: $SOAP_DEFAULT is not valid" unless $SOAP_VERSIONS{$SOAP_DEFAULT};
    return $SOAP_DEFAULT;
}

sub default_version { return default_soap_version; }

# Is the create sub needed?
#sub create {
#    my $class = shift;
#    my $self = $class->SUPER::create(@_);
#    unless ($self->arch_os =~ /64/) {
#        $self->error_message('Soap2 tools must be run from 64-bit architecture');
#        return;
#    }
#    unless ($self->temp_directory) {
#        my $base_temp_directory = Genome::Utility::FileSystem->base_temp_directory;
#        my $temp_dir = File::Temp::tempdir($base_temp_directory .'/Bowtie-XXXX', CLEANUP => 1);
#        Genome::Utility::FileSystem->create_directory($temp_dir);
#        $self->_tmp_dir($temp_dir);
#    }
#    return $self;
#}


1;

