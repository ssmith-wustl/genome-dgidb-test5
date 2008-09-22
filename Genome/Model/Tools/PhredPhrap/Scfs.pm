package Genome::Model::Tools::PhredPhrap::Scfs;

use strict;
use warnings;

use above "Genome";

require Cwd;
use Data::Dumper;
require Genome::Model::Tools::PhredPhrap::ScfToPhd;
require IO::File;

class Genome::Model::Tools::PhredPhrap::Scfs{
    is => 'Genome::Model::Tools::PhredPhrap',
    has => [],
};

sub help_brief {
    'Phrap starting with scfs in a chromat_dir';
}

sub _files_to_remove {
    return (qw/ default_phd_file /);
}

sub _handle_input {
    my $self = shift;

    $self->info_msg("Verifying SCFs");
    my $scf_file = $self->_verify_scfs;

    $self->info_msg("SCFs to PHD");
    $self->_scf2phd($scf_file);

    $self->info_msg("PHD to FASTA and Quality");
    $self->_phd2fnq( $self->default_phd_file );

    return 1;
}

sub _verify_scfs {
    my $self = shift;

    my $chromat_dir = $self->chromat_dir;
    my $dh = IO::Dir->new($chromat_dir)
        or ($self->error_message( sprintf('Can\'t open dir (%s): %s', $chromat_dir, $!) ) and return);

    my $scf_file = $self->default_scf_file;
    unlink $scf_file if -e $scf_file;
    my $scf_fh = IO::File->new("> $scf_file")
        or ($self->error_message("Can\'t open scf file ($scf_file) for writing: $!") and return);

    while ( my $scf_name = $dh->read ) {
        next unless $scf_name =~ /^(.+\.[bgasfrtpedxzyic]\d+)(\.gz)?$/;
        #next unless $scf_name =~ /^(.+\.\w\d+)(\.gz)?$/;

        # TODO Exclude

        $scf_fh->print("$1\n");
    }

    $dh->close;
    $scf_fh->close;

    ($self->error_message("No SCFs found in directory ($chromat_dir)") and return) unless -s $scf_file;

    return $scf_file;
}

sub _scf2phd {
    my ($self, $scf_file) = @_;
    my $scf2phd = Genome::Model::Tools::PhredPhrap::ScfToPhd-> new(
        scf_file => $scf_file,
        chromat_dir => $self->chromat_dir,
        phd_file => $self->default_phd_file,
        phd_dir => $self->phd_dir,
        #recall_phds => $self->recall_phds,
        #remove_all_phds => $self->remove_all_phds,
    );

    return $scf2phd->execute;
}

1;

#$HeadURL$
#$Id$
