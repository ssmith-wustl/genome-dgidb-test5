package Genome::Site::WUGC::Finishing::Project::Utils;

use strict;
use warnings;

use base 'Finfo::Singleton';

use Data::Dumper;
use Date::Format;
use Finfo::Validate;
use Filesystem::DiskUtil;
use IO::File;
use IO::String;
use ProjectWorkBench::Model::FinishingProject;

sub project_types
{
    return (qw/ gsc tmp /);
}

sub contig_sources
{
    return (qw/ ace gsc_seq /);
}

sub temp_project_dir
{
    return '/gscmnt/815/finishing/projects/tmp-projects';
}

sub open_outfile
{
    my ($self, $file) = @_;

    $self->_enforce_instance;

    Finfo::Validate->validate
    (
        attr => 'project output file',
        value => $file,
        type => 'output_file',
        err_cb => $self,
    );

    my $fh = IO::File->new("> $file");
    $self->error_msg("Can't open file ($file):\n$!")
        and return unless $fh;

    return $fh;
}

sub open_writer
{
    my ($self, $file) = @_;

    $self->_enforce_instance;

    my $fh = $self->open_outfile($file)
        or return;

    return Project::Writer->new(io => $fh);
}

sub open_infile
{
    my ($self, $file) = @_;

    $self->_enforce_instance;

    return unless Finfo::Validate->validate
    (
        attr => 'project input file',
        value => $file,
        type => 'input_file',
        err_cb => $self,
    );

    my $fh = IO::File->new("< $file");
    $self->error_msg("Can't open file ($file):\n$!")
        and return unless $fh;
    
    return $fh;
}

sub open_reader
{
    my ($self, $file) = @_;

    my $fh = $self->open_infile($file)
        or return;

    return Project::Reader->new(io => $fh);
}

sub contig_lookup_number
{
    my ($self, $ctg, $af_total) = @_;

    $self->error_msg("No contig to lookup")
        and return unless defined $ctg;

    $af_total = $af_total || 300;
    
    my $num = $ctg;
    $num =~ s/contig//ig;
    $num =~ s/\.\d+$//ig;
    
    return unless Finfo::Validate->validate
    (
        attr => "derived contig number ($num) from contig ($ctg)",
        value => $num,
        type => 'non_negative_integer',
        obj => $self,
    );
    
    return $num % $af_total;
}

sub _process_gsc_seq_param
{
    my ($self, $param) = @_;

    $self->error_msg("No param to get gsc item")
        and return unless defined $param;

    if ( $param =~ /^\d+$/ )
    {
        return (seq_id => $param);
    }
    else
    {
        return (sequence_item_name => $param);
    }
}

sub get_gsc_sequence_item
{
    my ($self, $param) = @_;

    my %p = $self->_process_gsc_seq_param($param);

    return unless %p;

    my $item = GSC::Sequence::Item->get(%p);

    $self->error_msg("Could not get GSC::Sequence for param ($param)") 
        and return unless defined $item;

    return $item;
}

sub get_gsc_sequence_pos
{
    my ($self, $param) = @_;

    my $item = $self->get_gsc_sequence_item($param);
    
    return unless $item;
    
    my $seq_pos = GSC::Sequence::Position->get(seq_id => $item->seq_id);
    
    $self->error_msg(sprintf('Could not get GSC::Sequence for seq_id (%s)', $item->seq_id))
        and return unless defined $seq_pos;

    return $seq_pos;
}

sub validate_new_seq_name
{
    my ($self, $name) = @_;

    $self->error_msg("No new name to validate")
        and return unless defined $name;
    
    $self->error_msg("Name ($name) already in db")
        and return if GSC::Sequence::Item->get(sequence_item_name => $name);
    
    return $name;
}

sub validate_project
{
    my ($self, $proj) = @_;

    Finfo::Validate->validate
    (
        attr => 'project name',
        value => $proj->{name},
        type => 'defined',
        err_cb => $self,
    );

    Finfo::Validate->validate
    (
        attr => 'project type',
        value => $proj->{type},
        type => 'in_list',
        options => [ project_types() ],
        err_cb => $self,
    );
    
    if ( $proj->{contigs} )
    {
        return unless $self->validate_contigs( $proj->{contigs} );
    }

    return 1
}

sub validate_contigs
{
    my ($self, $contigs) = @_;
    
    return unless Finfo::Validate->validate
    (
        attr => 'project contigs',
        value => $contigs,
        type => 'non_empty_hashref',
        err_cb => $self,
    );

    foreach my $name ( keys %$contigs )
    {
        return unless $self->validate_contig( $contigs->{$name} );
    }
    
    return 1;
}

sub validate_contig
{
    my ($self, $contig) = @_;

    return unless Finfo::Validate->validate
    (
        attr => 'parsed contig params',
        value => $contig,
        type => 'non_empty_hashref',
        err_cb => $self,
    );

    unless ( $contig->{aceinfo} or  $contig->{seqinfo} )
    {
        $self->error_msg("No contig source (aceinfo, seqinfo)");
        return;
    }
    
    if ( 0 )#$contig->{tags} )
    { # not implemented
        return unless Finfo::Validate->validate
        (
            attr => 'contig tags',
            value => $contig->{tags},
            type => 'non_empty_aryref',
            err_cb => $self,
        );

        # TODO check more tag attr?
    }

    if ( $contig->{start} or $contig->{stop} )
    {
        return unless Finfo::Validate->validate
        (
            attr => 'contig start pos',
            value => $contig->{start},
            type => 'positive_integer',
            err_cb => $self,
        );

        return unless Finfo::Validate->validate
        (
            attr => 'contig stop pos',
            value => $contig->{stop},
            type => 'positive_integer',
            err_cb => $self,
        );
    }

    return 1;
}

sub get_and_create_best_dir_for_project
{
    my ($self, $name) = @_;
    
    $self->fatal_error("No project name to create best dir") unless $name;

    my $project = GSC::Project->get(name => $name);
    
    my $abs_path = $project->consensus_abs_path;
    if ( $abs_path and -d $abs_path )
    {
        $project->consensus_directory($abs_path);
        return $abs_path;
    }

    my $projects_dir = $self->get_best_projects_dir;

    return unless $projects_dir;

    my $fp = ProjectWorkBench::Model::FinishingProject->new(name => $project->name)
        or return;
    
    my $org = $fp->organism_name
        or return;
    $org =~ s/\s+/_/g;
    
    my $org_dir = $projects_dir . '/' . $org;
    
    mkdir $org_dir unless -d $org_dir;
        
    $self->error_msg("Could not make org dir: $org_dir\:\n$!")
        and return unless -d $org_dir;

    my $proj_dir = $org_dir . '/' . $project->name;

    mkdir $proj_dir unless -d $proj_dir;

    $self->error_msg("Could not make proj dir: $proj_dir\:\n$!")
        and return unless -d $proj_dir;

    $project->consensus_directory($proj_dir);
    
    return $proj_dir;
}

sub get_best_projects_dir
{
    my $self = shift;
    
    my $projects_dir;
    my $count; # need this?
    do
    {
        $count++;
        $self->error_msg("Tried 10 times to get best finishing dir, but could not get one")
            and return if $count > 10;
        
        my $dir = Filesystem::DiskUtil->get_best_dir(group => 'finishing');

        $self->error_msg("Could not get best dir from disk utility")
            and return unless defined $dir;

        my $fin_dir = $dir . '/finishing';
        $projects_dir = $fin_dir . '/projects';

    } until -d $projects_dir;

    return $projects_dir;
}

sub _get_org_for_project_to_create_dir
{
    my ($self, $name) = @_;

    $self->error_msg("No name to get org to create dir")
        and return unless $name;
    
    my $fin_proj = ProjectWorkBench::Model::FinishingProject->new(name => $name)
        or return;

    my $org = $fin_proj->organism_name;
    $self->error_msg("Could determine organism for $name")
        and return unless defined $org;
    
    $org =~ s/ /_/;

    return $org;
}

sub create_consed_dir_structure
{
    my ($self, $base_dir) = @_;
    
    return unless Finfo::Validate->validate
    (
        attr => 'project path',
        value => $base_dir,
        type => 'output_path',
        err_cb => $self,
    );

    foreach my $type (qw/ edit_dir phd_dir chromat_dir /)
    {
        my $dir = "$base_dir/$type";

        mkdir $dir unless -e $dir;

        return unless Finfo::Validate->validate
        (
            attr => 'dir',
            value => $dir,
            type => 'output_path',
            err_cb => $self,
        );
    }

    return 1;
}

sub create_wg_clone_link_for_project
{
    my ($self, $project) = @_;

    $self->error_msg("No project to create clone-project link")
        and return unless $project;

    return 1 if GSC::CloneProject->get(project_id => $project->project_id);

    my ($clone) = GSC::Clone->get
    (
        sql =>
        "select * from clones where ct_clone_type = 'genome' and cs_clone_status = 'active' and clone_name like 'C\\_%' escape '\\'"
    );

    $self->error_msg("Can't get wg clone")
        and return unless $clone;

    my $new_cp = GSC::CloneProject->create
    (
        project_id => $project->project_id,
        clo_id => $clone->clo_id
    );

    $self->error_msg("Can't create clone proj link for " . $project->name)
        and return unless $new_cp;

    return $new_cp;
}

sub create_finishing_project
{
    my ($self, $project, $contigs) = @_;

    unless ( $project->{comment} =~ /first project/ )
    {
        my $stop = @$contigs[0]->get_padded_position(2000); #overlap

        GSC::Sequence::Tag::Finishing->create
        (
            subject_id => @$contigs[0]->id,
            begin_position => 1,
            end_position => $stop,
            finishing_tag_type => "doNotFinish",
            program => "project_maker",
            creation_time => Project::Utils->instance->tag_timestamp,
            no_trans => 0,
            seq_length => $stop,
        );
    }

    unless ( $project->{comment} =~ /last project/ )
    {
        my $start = @$contigs[-1]->get_padded_position
        (
            @$contigs[-1]->get_unpadded_position( @$contigs[-1]->seq_length ) - 2000 #overlap
        );
        my $stop = @$contigs[-1]->seq_length;

        GSC::Sequence::Tag::Finishing->create
        (
            subject_id => @$contigs[0]->id,
            begin_position => $start,
            end_position => $stop,
            finishing_tag_type => "doNotFinish",
            program => "project_maker",
            creation_time => Project::Utils->instance->tag_timestamp,
            no_trans => 0,
            seq_length => $stop - $start + 1,
        );
    }

    my $region = GSC::Sequence::Region->create
    (
        assembly => '1', #???
        sequence_item_name => $project->{name},
        children => $contigs
    )
        or confess("Could not create GSC::Sequence::Region for " . $project->{name} . "\n");

    my $fin_project = GSC::Setup::Project::Finishing->create
    (
        name => $project->{name},
        region => $region,
    )
        or confess "Could not create GSC::Setup::Project::Finishing for " . $project->{name} . "\n";         

    my $tp_entry = TpEntry->new
    (
    );

    confess unless $tp_entry;

    $tp_entry->create;

    return 1;
}

sub dump_acefile_for_finishing_project
{
    my ($self, $project) = @_;

    my $contigs;
    
    my $contig_string;
    my $contig_count = scalar @$contigs;
    my $read_count = 0;

    foreach my $contig ( @$contigs )
    {
        $read_count += $contig->read_count;
        $contig_string .= $contig->ace_content;
    }

    my $acefile = './edit_dir/' . $project->{name} . '.ace';
    unlink $acefile if -e $acefile;
    my $fh = IO::File->new("> $acefile");
    $fh->print("AS $contig_count $read_count\n\n$contig_string\n");
    $fh->close;

    return 1;
}

sub add_acefile_to_contig_name_for_agps
{
    my ($self, $proj, $access) = @_;

    return 1;

}

# Oragnism stuff
sub get_organism_for_project_name
{
    my ($self, $name) = @_;

    Finfo::Validate->validate
    (
        attr => 'project name',
        value => $name,
        type => 'defined',
        err_cb => $self,
    );

    my @prefixes;
    for (my $i = 2; $i <= 5; $i++)
    {
        my $prefix = substr($name,0,$i);
        last if $prefix =~ /-$/;
        push @prefixes, $prefix;
    }

    my $prefix_string = join(',', map { "'$_'" } @prefixes);

    my $dbh = DBI->connect
    (
        'dbi:Oracle:gscprod',
        'gscuser',
        'g_user',
        { AutoCommit => 0, RaiseError => 1 },
    );

    my $sth = $dbh->prepare
    (qq/
        select o.species_name, o.species_latin_name
        from dna_resource dr
        join entity_attribute_value eav on eav.entity_id = dr.dr_id
        join organism_taxon\@dw o on o.legacy_org_id = eav.value
        where eav.attribute_name = 'org id'
        and dr.dna_resource_prefix in ($prefix_string)
        order by dr.dna_resource_prefix DESC
        /);

    unless ( $sth and $sth->execute )
    {
        $dbh->disconnect;
        return;
    }

    my $aryref = $sth->fetchall_arrayref;

    $self->info_msg
    (
        "No organisms found for project name ($name) using prefix string ($prefix_string)"
    )
        and return unless $aryref and @$aryref;

    my ($common, $latin) = @{ $aryref->[0] }; 

    $dbh->disconnect;

    return 
    {
        common_name => $common || 'unknown',
        latin_name => $latin || $common || 'unknown' 
    };
}

sub get_organism_prefixes_and_dna_types
{
    my ($self, $org) = @_;

    Finfo::Validate->validate
    (
        attr => 'organism',
        value => $org,
        type => 'defined',
        err_cb => $self,
    );

    my $dbh = DBI->connect
    (
        'dbi:Oracle:gscprod',
        'gscuser',
        'g_user',
        { AutoCommit => 0, RaiseError => 1 },
    );

    my $sth = $dbh->prepare
    (qq/
        select dr.dna_resource_prefix, dr.incoming_type
        from organism_taxon\@dw o
        join entity_attribute_value eav on eav.value = o.legacy_org_id
        join dna_resource dr on dr.dr_id = eav.entity_id
        where eav.attribute_name = 'org id'
        and o.species_latin_name = '$org'
        /);

    unless ( $sth and $sth->execute )
    {
        $dbh->disconnect;
        return;
    }
    
    my $aryref = $sth->fetchall_arrayref;

    $self->info_msg("No prefixes found for organism ($org)")
        and return unless $aryref and @$aryref;
    
    my %orgs_dnas = map { $_->[0] => { dna_type => $_->[1] } } @$aryref;

    $dbh->disconnect;
    
    return \%orgs_dnas;
}

1;

