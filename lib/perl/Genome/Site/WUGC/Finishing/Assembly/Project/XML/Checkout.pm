package Genome::Site::WUGC::Finishing::Assembly::Project::XML::Checkout;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use Genome::Site::WUGC::Finishing::Assembly::Project::Checkout;
use Genome::Site::WUGC::Finishing::Assembly::Project::Utils;

my %xml :name(xml:r)
    :isa('object Genome::Site::WUGC::Finishing::Project::XML');

my %missed_db_traces :name(_missed_db_traces:p)
    :ds(aryref)
    :empty_ok(1)
    :default([]);

sub utils : PRIVATE
{
    return Genome::Site::WUGC::Finishing::Assembly::Project::Utils->instance;
}

sub execute
{
    my $self = shift;

    my $projects = $self->xml->read_projects;

    while ( my ($name, $project_info) = each %$projects )
    {
        my $checkout = Genome::Site::WUGC::Finishing::Assembly::Project::Checkout->new
        (
            name => $name,
            directory => $project_info->{directory},
            db => $project_info->{db},
            contigs => $project_info->{contigs},
        );
        $checkout->execute;
    }

    $self->xml->write_projects($projects);
    
    return 1;
}

1;

#HeadURL$
#$Id$
