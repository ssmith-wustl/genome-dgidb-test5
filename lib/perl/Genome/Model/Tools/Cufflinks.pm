package Genome::Model::Tools::Cufflinks;

use strict;
use warnings;

use Genome;
use File::Basename;

my $DEFAULT = '1.0.3';

class Genome::Model::Tools::Cufflinks {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => $DEFAULT, doc => "Version of cufflinks to use, default is $DEFAULT" },
    ],
};


sub help_brief {
    "Tools to run Cufflinks or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools cufflinks ...    
EOS
}

sub help_detail {
    return <<EOS
More information about the Cufflinks aligner can be found at http://cufflinks.cbcb.umd.edu/.
EOS
}


my %CUFFLINKS_VERSIONS = (
    '0.7.0'  => '/gsc/pkg/bio/cufflinks/cufflinks-0.7.0.Linux_x86_64',
    '0.8.0'  => '/gsc/pkg/bio/cufflinks/cufflinks-0.8.0.Linux_x86_64',
    '0.8.2'  => '/gsc/pkg/bio/cufflinks/cufflinks-0.8.2.Linux_x86_64',
    '0.8.3'  => '/gsc/pkg/bio/cufflinks/cufflinks-0.8.3.Linux_x86_64',
    '0.9.0'  => '/gsc/pkg/bio/cufflinks/cufflinks-0.9.0.Linux_x86_64',
    '0.9.1'  => '/gsc/pkg/bio/cufflinks/cufflinks-0.9.1.Linux_x86_64',
    '0.9.2'  => '/gsc/pkg/bio/cufflinks/cufflinks-0.9.2.Linux_x86_64',
    '0.9.3'  => '/gsc/pkg/bio/cufflinks/cufflinks-0.9.3.Linux_x86_64',
    '1.0.0'  => '/gsc/pkg/bio/cufflinks/cufflinks-1.0.0.Linux_x86_64',
    '1.0.1'  => '/gsc/pkg/bio/cufflinks/cufflinks-1.0.1.Linux_x86_64',
    '1.0.3'  => '/gsc/pkg/bio/cufflinks/cufflinks-1.0.3.Linux_x86_64',
);

sub gtf_to_sam_path {
    my $self = $_[0];
    unless (version->parse($self->use_version) >= version->parse('1.0.1')) {
        die('gtf_to_sam command not available with version: '. $self->use_version);
    }
    return $self->path_for_cufflinks_version($self->use_version) .'/gtf_to_sam';
}

sub gffread_path {
    my $self = $_[0];
    unless (version->parse($self->use_version) >= version->parse('1.0.1')) {
        die('gffread command not available with version: '. $self->use_version);
    }
    return $self->path_for_cufflinks_version($self->use_version) .'/gffread';
}

sub cuffmerge_path {
    my $self = $_[0];
    unless (version->parse($self->use_version) >= version->parse('1.0.0')) {
        die('cuffmerge command not available with version: '. $self->use_version);
    }
    return $self->path_for_cufflinks_version($self->use_version) .'/cuffmerge';
}

sub cuffcompare_path {
    my $self = $_[0];
    return $self->path_for_cufflinks_version($self->use_version) .'/cuffcompare';
}

sub cuffdiff_path {
    my $self = $_[0];
    return $self->path_for_cufflinks_version($self->use_version) .'/cuffdiff';
}

sub cufflinks_path {
    my $self = $_[0];
    return $self->path_for_cufflinks_version($self->use_version) .'/cufflinks';
}

sub available_cufflinks_versions {
    my $self = shift;
    return keys %CUFFLINKS_VERSIONS;
}

sub path_for_cufflinks_version {
    my $class = shift;
    my $version = shift;

    if (defined $CUFFLINKS_VERSIONS{$version}) {
        return $CUFFLINKS_VERSIONS{$version};
    }
    die('No path for cufflinks version '. $version);
}

sub default_cufflinks_version {
    die "default cufflinks version: $DEFAULT is not valid" unless $CUFFLINKS_VERSIONS{$DEFAULT};
    return $DEFAULT;
}

1;

