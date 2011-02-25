package Finishing::Project::Factory;

use strict;
use warnings;

use base 'Finfo::Singleton';

use Bio::SeqIO;
use Data::Dumper;
use Finishing::Project;
use Finishing::Project::FileReader;
use Finishing::Project::GSC;
use Finishing::Project::Proxies;
use Finishing::Project::Sources;
use Finishing::Project::Utils;
use IO::File;

sub get_project
{
    my ($self, %p) = @_;

    $self->_enforce_instance;
    
    my $name = delete $p{name};
    my $dir = delete $p{dir};
    my $isa_gsc_proj = delete $p{isa_gsc_proj};
    
    my ($project_class, $proxy_class, $source);
    if ( $name )
    {
        $project_class = 'Finishing::Project::GSC';
        $proxy_class = 'Finishing::Project::GSCProxy';
        use GSCApp;
        App->init unless App::Init->initialized;
        $source = GSC::Project->get(name => $name);
    }
    
    unless ( $source )
    {
        $self->fatal_msg("Can't get GSC project ($name)") if $isa_gsc_proj;
        my %src_params;
        $src_params{name} = $name if $name;
        $src_params{dir} = $dir if $dir;
        $project_class = 'Finishing::Project';
        $source = Finishing::Project::Source->new(%src_params);
        $proxy_class = 'Finishing::Project::Proxy';
    }
    
    my $proxy = $proxy_class->new
    (
        source => $source,
    );
    
    return $project_class->new
    (
        proxy => $proxy,
    );
}

sub create_projects
{
    my ($self, $xml) = @_;

    $self->_enforce_instance;

    Finfo::Validate->validate
    (
        attr => 'project xml',
        value => $xml,
        isa => 'object Finishing::Project::XML',
        msg => 'fatal',
    );

    my $projects = $xml->read_projects;

    foreach my $name ( keys %$projects )
    {
        my $method = sprintf('_create_%s_project', $projects->{$name}->{type});
        $projects->{$name}->{dir} = $self->$method($name);
    }

    return $xml->write_projects($projects);
}

sub utils : PRIVATE
{
    return Finishing::Project::Utils->instance;
}

sub _create_tmp_projects : PRIVATE
{
    my ($self, $name) = @_;

    my $dir = $self->utils->tmp_project_dir;

    $self->error_msg("Tmp projects dir ($dir) does not exist")
        and return unless -d $dir;

    my $proj_dir = "$dir/$name";
    mkdir $proj_dir unless -e $proj_dir;

    $self->fatal_msg("Can't create project dir ($proj_dir): $!") unless -d $proj_dir;

    return $proj_dir;
}

sub _create_gsc_project : PRIVATE
{
    my ($self, $name) = @_;

    my $gsc_proj = GSC::Project->get(name => $name);

    return $gsc_proj->consensus_abs_path if $gsc_proj;

    my $ps = GSC::ProcessStep->get
    (
        process_to => 'new project',
        process => 'new project',
    );

    $self->fatal_msg("Can't get new project process step") unless $ps;

    my $pse = $ps->execute
    (
        name => $name,
        project_status => 'prefinish_done',
        target => 0,
        purpose => 'finishing',
        group_name => 'crick',
        priority => 0,
    );

    $self->fatal_msg
    (
        "Can't execute new project process step for $name"
    ) unless $pse;

    $gsc_proj = GSC::Project->get(name => $name);

    $self->fatal_msg("Executed pse, but can't project from db") unless $gsc_proj;

    return $self->utils->get_and_create_best_dir_for_project($name);
}

sub _create_gsc_sequence_projects
{
    my ($self, $projects) = @_;

    $self->fatal_msg("Not implemented");
}

1;

