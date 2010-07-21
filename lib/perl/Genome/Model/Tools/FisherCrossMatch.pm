package Genome::Model::Tools::FisherCrossMatch;

use strict;
use warnings;

use Genome;
use Data::Dumper;

#
# This is a wrapper class allowing autoload of Ken Chen's Fisher Test based CrossMatch module.
#
#######################################################################

class Genome::Model::Tools::FisherCrossMatch {
    is => 'Command',
    has => {
        use_version => {is=>'Text', default_value=>'2010-02-10', doc=>'Version to use'}
    }
};

our %VERSIONS = (
    '2010-02-10' => '/gsc/scripts/pkg/bio/fisher_crossmatch/fisher_crossmatch-2010-02-10'
    );

sub sub_command_sort_position { 14 }

sub create {
    my $class = shift;
    
    my $self = $class->SUPER::create(@_);

    $self->load_perl;

}

sub load_perl {
    my $self = shift;
    printf("Autoloading fisher crossmatch version %s\n", $self->use_version);
    my $lib_dir = $VERSIONS{$self->use_version};
    if (!$lib_dir) {
        die "Could not find a lib dir for " . $self->use_version . " Valid dirs are " . Dumper(\%VERSIONS);
    }
    printf("fisher crossmatch directory %s\n", $lib_dir);
    if (!-d $lib_dir || !-f $lib_dir . "/CrossMatch.pm") {
        die "No CrossMatch.pm exists in $lib_dir, or $lib_dir for use_version " . $self->use_version . " doesn't exist";
    }
    eval qq|
        use lib qw($lib_dir);
        use CrossMatch;
    |;
}

sub help_brief {
    "Tools to load Fisher statistical test based crossmatch module.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
EOS
}

sub help_detail {
    return <<EOS
EOS
}

1;

