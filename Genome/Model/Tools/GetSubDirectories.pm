package Genome::Model::Tools::GetSubDirectories;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::GetSubDirectories{
    is => 'Genome::Model::Tools',
    has => [
        dir => {is => 'String', doc => 'path for parent directory'},
    ] ,
    has_output => [
        sub_directories => { is => 'ARRAY',  doc => 'array of sub directories', is_optional => 1 },
    ],
};

sub help_brief {
    "produce a list of sub directories for given parent directory"
}

sub help_synopsis {
    return <<"EOS"

produce a list of sub directories for parent directory 
EOS
}

sub help_detail {
    return <<"EOS"

takes a path for parent directory and returns list of sub directories
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute
{
    my $self = shift;
    my $dir = $self->dir;
    my @sub_dirs;

    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (sort readdir DH) 
    { 
	if (!($name =~ /\./)) {
		my $full_path = $dir."/".$name;
		if (-d $full_path) 
                { 
                    # is a directory
                    push @sub_dirs, $full_path; #use absolute paths instead of relative
		}
	}
    }
    $self->sub_directories(\@sub_dirs);
    return 1;
}

1;
