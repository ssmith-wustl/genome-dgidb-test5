package Genome::Site::WUGC::Finishing::Project::ConvertFromFile;

use strict;
use warnings;

use Finfo::Std;

use Bio::SeqIO;
use Data::Dumper;
use Genome::Site::WUGC::Finishing::Project::Utils;
use IO::File;

my %namer :name(namer:r)
    :type(inherits_from)
    :options([qw/ Genome::Site::WUGC::Finishing::Project::Namer /]);
my %filereader :name(filereader:r) 
    :type(inherits_from)
    :options([qw/ Genome::Site::WUGC::Finishing::Project::FileReader /]);
my %xml :name(xml:r)
    :type(inherits_from)
    :options([qw/ Genome::Site::WUGC::Finishing::Project::XML /]);
my %type :name(type:r)
    :type(in_list)
    :options([ Genome::Site::WUGC::Finishing::Project::Utils->project_types ])
    :clo('type=s')
    :desc( sprintf('Type of project: %s', join(', ', Genome::Site::WUGC::Finishing::Project::Utils->project_types)) );

sub execute
{
    my $self = shift;

    my $projects;
    while ( my $proj = $self->filereader->next )
    {
        my $name = $self->namer->next_name
            or return;
        $projects->{$name} = $proj;
        $projects->{$name}->{type} = $self->type;
    }

    $self->xml->write_projects($projects);

    return 1;
}

1;

