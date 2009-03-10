package Genome::Model::Tools::Velvet;

use strict;
use warnings;

use POSIX;
use Genome;

class Genome::Model::Tools::Velvet {
    is  => 'Command',
    is_abstract => 1,
    has => [
        version => {
            is   => 'String',
            doc  => 'velvet version, must be one of old, installed, test. default is installed',
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
gt velvet ...
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

    my @uname = POSIX::uname();
    my $ver   = $self->version;
    $ver .= '-64' if $uname[4] eq 'x86_64';
    
    my $exec = "/gsc/pkg/bio/velvet/$ver/$type";
    unless (-x $exec) {
        $self->error_message("$exec is not excutable");
        return;
    }

    return $exec;
}

    
1;

