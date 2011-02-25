package Genome::Site::WUGC::Finishing::Project::Checkout;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use Genome::Site::WUGC::Finishing::Assembly::Ace::Ext;
use Genome::Site::WUGC::Finishing::Project::Utils;
use GSC::IO::Assembly::Ace;
use GSC::IO::Assembly::Ace::Writer;
use GSC::Sequence::Assembly::AceAdaptor;
use IO::File;
use NCBI::TraceArchive;

require Compress::Zlib;
require File::Basename;
require File::Copy;

my %xml :name(xml:r)
    :type(inherits_from)
    :options([qw/ Genome::Site::WUGC::Finishing::Project::XML /]);

my %missed_db_traces :name(_missed_db_traces:p) :type(aryref) :default([]);

sub utils : PRIVATE
{
    return Genome::Site::WUGC::Finishing::Project::Utils->instance;
}

sub execute
{
    my $self = shift;

    my $projects = $self->xml->read_projects;

    $self->fatal_error
    (
        sprintf('No projects found in xml file (%s)', $self->xml->file)
    ) unless $projects;
    
    foreach my $name ( keys %$projects )
    {
        $self->info_msG("Checking out $name");
        my $fin_proj = Genome::Site::WUGC::Finishing::Project->new(dir => $projects->{$name}->{dir});
        $fin_proj->create_consed_dir_structure;

        my ($co_type) = grep { exists $projects->{$name}->{$_} } (qw/ acefile ctgs seq_region /);
        my $co_method = "_checkout_$co_type";
        $self->$co_method($fin_proj, $projects->{$name});
    }

    return 1;
}

sub _checkout_acefile
{
    my ($self, $fin_project, $xml_project) = @_;

    my $dir = $xml_project->{dir};
    Finfo::Validate->validate
    (
        attr => 'project directory',
        value => $dir,
        type => 'output_path',
        err_cb => $self,
    );
    
    my $old_acefile = $xml_project->{acefile};
    Finfo::Validate->validate
    (
        attr => 'project acefile',
        value => $old_acefile,
        type => 'input_file',
        err_cb => $self,
    );
 
    my $acebase = File::Basename::basename($old_acefile);
    my $acefile = "$dir/edit_dir/$acebase";

    unless ( -e $acefile )
    {
        #File::Copy::move($acefile, $new_acefile)
        File::Copy::copy($old_acefile, $acefile)
            or $self->fatal_msg("Can't copy $old_acefile to $acefile\: $!");
    }

    my $ace = GSC::IO::Assembly::Ace->new(input_file => $acefile)
        or return;

    my $aceext = Genome::Site::WUGC::Finishing::Assembly::Ace::Ext->new(ace => $ace)
        or return;

    my $reads = $aceext->get_reads;
    $self->error_msg("No reads found in ace ($acefile)")
        and return unless defined $reads and @$reads;

    my %read_names;
    foreach my $read (@$reads)
    {
        my $name = $read->name;
        $name =~ s/\.scf//;
        $read_names{$name} = 1;
    }
    
    # try to get reads from db first...
    my @db_reads = GSC::Sequence::Item->get
    (
        sequence_item_name => [ map { "$_-1" } keys %read_names ]
    );

    if ( @db_reads )
    {
        $self->_export_scfs_and_phds($fin_project, \@db_reads)
            or return;

        # remove the db reads from the list reads to get
        foreach my $db_read ( @db_reads )
        {
            my $name = $db_read->sequence_item_name;
            $name =~ s/\-\d+$//;
            delete $read_names{$name};
        }
    }

    # get traces from trace archive
    return unless $self->_retrieve_traces_from_the_trace_archive
    (
        $fin_project, 
        keys %read_names, @{ $self->_missed_db_traces }
    );    

    $fin_project->touch_singlets_file_for_acefile($acefile);

    unlink $acefile . '.db' if -e $acefile . '.db';
    
    return 1;
}

sub _checkout_ctgs : PRIVATE
{
    my ($self, $project) = @_;

    Finfo::Validate->validate
    (
        attr => 'project directory',
        value => $project->{dir},
        type => 'output_path',
        err_cb => $self,
    );
    
    my $acefile = sprintf('%s/edit_dir/%s.fasta.screen.ace', $project->{dir}, $project->{name});
    unlink $acefile;
    unlink $acefile . '.db';
    return unless Finfo::Validate->validate
    (
        attr => 'project acefile',
        value => $acefile,
        type => 'output_file',
        #type => 'file',
        err_cb => $self,
    );

    my $ace = GSC::IO::Assembly::Ace->new();
    return unless $ace;

    Genome::Site::WUGC::Finishing::Project::ContigCollector->instance->execute($project, $ace)
        or return;

    $ace->write_file(output_file => $acefile);

    return unless Finfo::Validate->validate
    (
        attr => 'project acefile',
        value => $acefile,
        type => 'input_file',
        err_cb => $self,
    );

    $self->_touch_singlets_file_for_acefile($acefile); # for consed

    $self->info_msg("Getting reads and phds for $project->{name}");
    
    my $acemodel = Genome::Site::WUGC::Finishing::ProjectWorkBench::Model::Ace->new(aceobject => $ace)
        or return;

    my $reads = $acemodel->contigs_to_reads;
    $self->error_msg("No reads found in ace ($acefile)")
        and return unless defined $reads and @$reads;

    my %read_names;
    foreach my $read (@$reads)
    {
        my $name = $read->name;
        $name =~ s/\.scf//;
        $read_names{$name} = 1;
    }
    
    # try to get reads from db first...
    my @db_reads = GSC::Sequence::Item->get
    (
        sequence_item_name => [ map { "$_-1" } keys %read_names ]
    );

    $self->error_msg("Could not get db reads for reads in ace ($acefile)")
        and return unless @db_reads;

    $self->_export_scfs_and_phds($project, \@db_reads)
        or return;

    # remove the db reads from the list reads to get
    foreach my $db_read ( @db_reads )
    {
        my $name = $db_read->sequence_item_name;
        $name =~ s/\-\d+$//;
        delete $read_names{$name};
    }
    
    # get traces from trace archive
    return unless $self->_retrieve_traces_from_the_trace_archive
    (
        $project, 
        keys %read_names, @{ $self->_missed_db_traces }
    );    

    unlink $acefile . '.db' if -e $acefile . '.db';
    
    return 1;
}

sub _checkout_gsc_sequence_region : PRIVATE
{
    my ($self, $project) = @_;

    my $region = Genome::Site::WUGC::Finishing::Project::Utils->instance->get_gsc_sequence_item
    (
        $project->{seq_region_id} 
    )
        or return;
    my $region_name = $region->sequence_tem_name;

    # lock region
    $self->error_message("Unable to lock region ($region_name)")
        and return unless $region->lock;

    # acefile
    my $acefile = sprintf('%s/edit_dir/%s.fasta.screen.ace', $project->{dir}, $region_name);

    $self->_touch_singlets_file_for_acefile($acefile); # singlets file for consed

    my $writer = GSC::IO::Assembly::Ace::Writer->new( IO::File->new("> $acefile") );
    $self->error_msg("Can't create ace writer")
        and return unless $writer;

    my $assembly = $region->get_assembly;
    $self->error_msg("No assembly found for region ($region_name)")
        and return unless $region;
    
    my @contigs = $region->get_contigs;
    $self->error_msg("No contigs found for region ($region_name)")
        and return unless @contigs;

    my $adaptor = GSC::Sequence::Assembly::AceAdaptor->new();
    $self->error_msg("Can't create ace adaptor")
        and return unless $adaptor;

    $self->error_message("Failed to export ace file for ($region_name)")
        and return unless $adaptor->export_assembly
    (
        writer => $writer,
        assembly => $assembly,
        contigs => \@contigs,
    );

    # scfs/phds
    my @reads = $region->get_reads;
    $self->("No reads in region ($region_name)")
        and return unless @reads;

    $self->_export_scfs_and_phds($project, \@reads)
        or return;

    $self->_retrieve_traces_from_the_trace_archive($project, @{ $self->_missed_db_traces });
    
    return 1;
}

sub _export_scfs_and_phds : PRIVATE
{ 
    my ($self, $fin_project, $reads) = @_;

    return unless Finfo::Validate->validate
    (
        attr => 'reads to export',
        value => $reads,
        type => 'non_empty_aryref',
        err_cb => $self,
    );

    my $chromat_dir = $fin_project->chromat_dir;
    my $phd_dir = $fin_project->phd_dir;

    foreach my $read ( @$reads )
    {
        my $scf_name = sprintf('%s/%s.gz', $chromat_dir, $read->default_file_name('scf'));
        $self->error_msg("Could not get default scf name for " . $read->sequence_item_name)
            and return unless defined $scf_name;
        next if -e $scf_name;
        my $scf_fh = IO::File->new("> $scf_name");
        $self->error_msg("Can't open scf ($scf_name)\n$!")
            and return unless $scf_fh;
        $scf_fh->print( Compress::Zlib::memGzip( $read->scf_content ) );
        $scf_fh->close;

        unless ( -s $scf_name )
        {
            push @{ $self->_missed_db_traces }, $read->name;
            $self->info_msg("No scf content for " . $read->name);
            next;
        }
        
        my @read_edits = ( $read );
        push @read_edits, ( $read->get_read, $read->get_previous_edits ) if $read->isa('GSC::Sequence::ReadEdit');
        
        foreach my $read_edit ( @read_edits )
        {
            my $phd_name = sprintf('%s/%s', $phd_dir, $read_edit->default_file_name('phd'));
            $self->error_msg('Could not get default phd name for ' . $read->sequence_item_name)
                and return unless defined $phd_name;
            if ( -e $phd_name )
            {
                next;
                $self->info_msg("Phd exists: $phd_name");
                unlink $phd_name;
            }
                
            my $phd_fh = IO::File->new("> $phd_name");
            $self->error_msg("Can't open phd ($phd_name):\n$!")
                and return unless $phd_fh;

            $phd_fh->print( $read_edit->phd_content );
            $phd_fh->close;
        }
    }

    return 1;
}

# ta
sub _retrieve_traces_from_the_trace_archive : PRIVATE
{
    my ($self, $fin_project, @read_names) = @_;

    return 1 unless @read_names;
    
    my $ta = NCBI::TraceArchive->new
    (
        dir => '/tmp',
        sources => \@read_names,
    )
        or return;

    my $retrieved_traces = $ta->retrieve
        or return;

    return $fin_project->process_ncbi_traces
    (
        trace_location => '/tmp',
        traces => $retrieved_traces,
    );
}

sub _create_gsc_seq_fin_project
{
    my ($self, $project) = @_;

    my $proj_utils = Project::Utils->instance
        or die;

    return unless $proj_utils->validate_project($project);

    my $gsc_seq_proj = GSC::Sequence::Setup::Genome::Site::WUGC::Finishing::Project->get(name => $project->{name});

    unless ( $gsc_seq_proj )
    {
        return unless $proj_utils->validate_new_seq_name($project->{name});

        $gsc_seq_proj = GSC::Sequence::Setup::Genome::Site::WUGC::Finishing::Project->new
        (
            name => $project->{name},
            project_status => 'prefinish_done',
            target => 0,
            purpose => 'finishing',
            group_name => 'crick',
            priority => 0,
        );

        $self->error_msg
        (
            "Could not create GSC::Sequence::Setup::Genome::Site::WUGC::Finishing::Project for $project->{name}"
        )
            and return unless $gsc_seq_proj;

    }

    $proj_utils->create_project_dir_structure( $gsc_seq_proj )
        or return;
    
    #$self->info_msg("Created dir $project->{dir}");

    return $gsc_seq_proj;
}


1;

