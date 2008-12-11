package Genome::Model::Tools::454;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use File::Temp;

class Genome::Model::Tools::454 {
    is => ['Command'],
    has => [
            arch_os => {
                        calculate => q|
                            my $arch_os = `uname -m`;
                            chomp($arch_os);
                            return $arch_os;
                        |
                    },
        ],
    has_optional => [
                     version => {
                                 is    => 'string',
                                 doc   => 'version of 454 application to use',
                             },
                     _tmp_dir => {
                                  is => 'string',
                                  doc => 'a temporary directory for storing files',
                              },
                 ]
};

sub help_brief {
    "tools to work with 454 reads"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS

EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless ($self->arch_os =~ /64/) {
        $self->error_message('All 454 tools must be run from 64-bit architecture');
        return;
    }

    my $tempdir = File::Temp::tempdir(CLEANUP => 1);
    $self->_tmp_dir($tempdir);

    unless ($self->version) {
        my $base_path = $self->resolve_454_path .'installed';
        if (-l $base_path) {
            my $link = readlink($base_path);
            unless ($link =~ /offInstrumentApps-(\d\.\d\.\d{2}\.\d{2})-64/) {
                $self->error_message('Link to 454 tools was malformed: '. $link);
                return;
            }
            $self->version($1);
        } else {
            $self->error_message('Expected symlink to installed software');
            return;
        }
    }
    unless ($self->version) {
        $self->error_message('Failed to resolve version number of 454 applications');
        return;
    }
    return $self;
}

sub resolve_454_path {
    return '/gsc/pkg/bio/454/';
}

sub bin_path {
    my $self = shift;
    return $self->resolve_454_path .'offInstrumentApps-'. $self->version .'-64/bin';
}

1;

