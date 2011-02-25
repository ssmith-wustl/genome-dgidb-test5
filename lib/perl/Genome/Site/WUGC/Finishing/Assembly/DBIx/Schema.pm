package Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

use Data::Dumper;
use Finfo::Logging 'fatal_msg';
use Finfo::Validate;
use XML::Simple;

require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::AssembledRead;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::AssembledReadSequence;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Assembly;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::AssemblyTag;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Chromosome;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ChromosomeFirstScaffold;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ConsensusSequence;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ConsensusTag;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Contig;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::CorrelationContig;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Event;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Gap;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ImprovementCorrelation;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Library;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Organism;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Project;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ReadTag;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ReplacedContig;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ReplacedContigEvent;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Scaffold;
require Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::TemplateLink;

__PACKAGE__->register_class('Chromosome', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Chromosome');
__PACKAGE__->register_class('ChromosomeFirstScaffold', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ChromosomeFirstScaffold');
__PACKAGE__->register_class('Scaffold', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Scaffold');
__PACKAGE__->register_class('Library', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Library');
__PACKAGE__->register_class('AssembledRead', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::AssembledRead');
__PACKAGE__->register_class('Gap', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Gap');
__PACKAGE__->register_class('AssembledReadSequence', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::AssembledReadSequence');
__PACKAGE__->register_class('ConsensusSequence', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ConsensusSequence');
__PACKAGE__->register_class('AssemblyTag', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::AssemblyTag');
__PACKAGE__->register_class('ConsensusTag', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ConsensusTag');
__PACKAGE__->register_class('Organism', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Organism');
__PACKAGE__->register_class('Assembly', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Assembly');
__PACKAGE__->register_class('Contig', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Contig');
__PACKAGE__->register_class('ReadTag', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ReadTag');
__PACKAGE__->register_class('TemplateLink', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::TemplateLink');
__PACKAGE__->register_class('ImprovementCorrelation', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ImprovementCorrelation');
__PACKAGE__->register_class('CorrelationContig', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::CorrelationContig');
__PACKAGE__->register_class('Event', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Event');
__PACKAGE__->register_class('Project', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::Project');
__PACKAGE__->register_class('ProjectContig', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ProjectContig');
__PACKAGE__->register_class('ReplacedContig', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ReplacedContig');
__PACKAGE__->register_class('ReplacedContigEvent', 'Genome::Site::WUGC::Finishing::Assembly::DBIx::Schema::ReplacedContigEvent');

sub disconnect
{
    my $self = shift;

    return $self->storage->disconnect if $self->storage;
}

sub DESTROY
{
    my $self = shift;

    return $self->disconnect;
}

#- ORGANISM -#
sub get_organisms
{
    my $self = shift;

    return $self->resultset('Organism')->all;
}

sub organisms
{
    my $self = shift;

    return $self->resultset('Organism');
}

sub get_organism
{
    my ($self, $name) = @_;

    Finfo::Validate->validate
    (
        attr => 'organism name',
        value => $name,
        isa => 'string',
        msg => 'fatal',
    );
    
    return $self->resultset('Organism')->find({ name => $name });
}

sub get_or_create_organism
{
    my ($self, $name) = @_;
    my $organism;
    return $self->create_organism($name) unless $organism = $self->get_organism($name);
    return $organism;
}

sub create_organism
{
    my ($self, $name) = @_;

    Finfo::Validate->validate
    (
        attr => 'organism name',
        value => $name,
        isa => 'string',
        msg => 'fatal',
    );
    
    my $existing_organism = $self->get_organism($name);
    $self->fatal_msg("Can't create organism ($name), it already exists") if $existing_organism;
    
    my $organism = $self->resultset('Organism')->create({ name => $name });
    $self->fatal_msg("Can't create organism ($name)") unless $organism;

    return $organism;
}

#- ASSEMBLY -#
sub get_assembly
{
    my ($self, %p) = @_;

    if ( my $id = delete $p{id} )
    {
        return $self->resultset('Assembly')->find($id);
    }

    my $organism_name = delete $p{organism_name};
    my $organism = $self->get_organism($organism_name)
        or $self->fatal_msg("Can't get organism ($organism_name)");

    return $organism->get_assembly( delete $p{name} );
}

sub create_assembly
{
    my ($self, %p) = @_;

    my $organism_name = delete $p{organism_name};
    my $organism = $self->get_organism($organism_name)
        or $self->fatal_msg("Can't get organism ($organism_name)");

    return $organism->create_assembly( delete $p{name} );
}

sub get_or_create_assembly
{
    my ($self, %p) = @_;

    my $organism_name = delete $p{organism_name};
    my $organism = $self->get_organism($organism_name)
        or $self->fatal_msg("Can't get organism ($organism_name)");

    return $organism->get_or_create_assembly( delete $p{name} );
}

#- PROJECT -#
sub get_project
{
    my ($self, $name) = @_;

    Finfo::Validate->validate
    (
        attr => 'dbix project name',
        value => $name,
        isa => 'string',
        msg => 'fatal',
    );

    return $self->resultset("Project")->find({ name => $name })
}

sub create_project
{
    my ($self, %p) = @_;

    my $name = delete $p{name};
    Finfo::Validate->validate
    (
        attr => 'project name',
        value => $name,
        isa => 'string',
        msg => 'fatal',
    );

    my $organism_name = delete $p{organism_name};
    my $organism = $self->get_organism($organism_name);
    $self->fatal_msg("Can't get organism($organism_name)") unless $organism;
    
    my $base_directory = delete $p{base_directory};
    my $directory;
    unless ( $base_directory )
    {
        $directory = Genome::Site::WUGC::Finishing::Assembly::Project::Utils->instance->determine_and_create_projects_directory
        (
            $name, 
            $organism_name
        );
    }
    else
    {
        $directory = sprintf('%s/%s', $base_directory, $name);

        unless ( -d $directory )
        {
            mkdir $directory
                or $self->fatal_msg("Can't create directory ($directory) for $name\: $!");
        }
    }

    return $self->resultset('Project')->find_or_create
    (
        {
            name => $name,
            directory => $directory,
            organism_id => $organism->id,
        }
    )
        or $self->fatal_msg("Can't find or create project ($name)");
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/branches/adukes/AssemblyRefactor/Schema.pm $
#$Id: Schema.pm 31442 2008-01-03 23:47:59Z adukes $
