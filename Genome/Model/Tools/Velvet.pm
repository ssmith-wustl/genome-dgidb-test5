package Genome::Model::Tools::Velvet;

use strict;
use warnings;

use POSIX;
use Genome;
use Data::Dumper;
use Regexp::Common;

class Genome::Model::Tools::Velvet {
    is  => 'Command',
    is_abstract  => 1,
    has_optional => [
        version => {
            is   => 'String',
            doc  => 'velvet version, must be valid velvet version number like 0.7.22, 0.7.30. It takes installed as default.',
            default => 'installed',
        },
    ],
};

sub sub_command_sort_position { 14 }

sub help_brief {
    "Tools to run velvet, a short reads assembler, and work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt velvet ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}


sub resolve_version {
    my $self = shift;

    my ($type) = ref($self) =~ /\:\:(\w+)$/;
    $type = 'velvet'.lc(substr $type, 0, 1);

    my $ver = $self->version;
    $ver = 'velvet_'.$ver unless $ver eq 'installed';
    
    my @uname = POSIX::uname();
    $ver .= '-64' if $uname[4] eq 'x86_64';
    
    my $exec = "/gsc/pkg/bio/velvet/$ver/$type";
    unless (-x $exec) {
        $self->error_message("$exec is not excutable");
        return;
    }

    return $exec;
}
   
1;

