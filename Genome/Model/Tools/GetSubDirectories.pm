package Genome::Model::Tools::GetSubDirectories;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::GetSubDirectories{
    is => 'Genome::Model::Tools::ViromeEvent',
    has_output => [
        sample_directories => { is => 'ARRAY',  doc => 'array of sample directories', is_optional => 1 },
    ],
};

sub help_brief {
    "produce a list of sample directories for virome operations"
}

sub help_synopsis {
    return <<"EOS"

produce a list of sample directories for virome operations
EOS
}

sub help_detail {
    return <<"EOS"

produce a list of sample directories for virome operations

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
    my @sample_dirs;

    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (sort readdir DH) 
    { 
	if (!($name =~ /\./)) {
		my $full_path = $dir."/".$name;
		if (-d $full_path) 
                { 
                    # is a directory
                    push @sample_dirs, $full_path; #use absolute paths instead of relative
		}
	}
    }
    $self->sample_directories(\@sample_dirs);
    return 1;
}

1;
