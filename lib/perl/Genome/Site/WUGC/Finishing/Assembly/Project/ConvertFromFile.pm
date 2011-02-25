package Genome::Site::WUGC::Finishing::Assembly::Project::ConvertFromFile;

use strict;
use warnings;

use Finfo::Std;

use Bio::SeqIO;
use Data::Dumper;
use Genome::Site::WUGC::Finishing::Assembly::Project::Utils;
use IO::File;

my %namer :name(namer:r)
    :isa('object Genome::Site::WUGC::Finishing::Assembly::Project::Namer');
my %filereader :name(filereader:r) 
    :isa('object Genome::Site::WUGC::Finishing::Assembly::Project::FileReader');
my %xml :name(xml:r)
    :isa('object Genome::Site::WUGC::Finishing::Assembly::Project::XML');
my %type :name(type:r)
    :isa([ 'in_list', Genome::Site::WUGC::Finishing::Assembly::Project::Utils->project_types ])
    :clo('type=s')
    :desc( sprintf('Type of project: %s', join(', ', Genome::Site::WUGC::Finishing::Assembly::Project::Utils->project_types)) );

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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Assembly/Project/ConvertFromFile.pm $
#$Id: ConvertFromFile.pm 31534 2008-01-07 22:01:01Z ebelter $
