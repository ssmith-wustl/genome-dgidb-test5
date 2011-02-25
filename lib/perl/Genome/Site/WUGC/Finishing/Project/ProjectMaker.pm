package Project::GUI;

use strict;
use warnings;

use base qw(Finfo::Object);

use App::UI::Gtk2::View;
use Data::Dumper;

sub _attrs
{
    return 
    {
        '_working_frame:p' =>
        {
            type => 'inherits_from',
            options => [qw/ Gtk2::Frame /],
        },
        '_working_box:p' => 
        {
            type => 'inherits_from',
            options => [qw/ Gtk2::VBox /],
        },
    };
}
sub execute
{
    my $self = shift;

    my $view = App::UI::Gtk2::View->instance;

    my $dialog = $view->create_dialog
    (
        title => 'Project Maker',
        dparams =>[  'gtk-ok' => 1, 'gtk-cancel' => 0 ],
    );

    $view->add_menu
    (
        parent => $dialog->vbox,
        menu_tree => 
        [ 
        File =>
        {
            item_type => '<Branch>',
            children =>
            [
            Save => 
            { 
                item_type => '<StockItem>',
                extra_data => 'gtk-save',
                callback => sub
                {
                    $self->save_text_to_file_select
                    (
                        $view->get_text_from_basic_text( $self->_text_buffer ) 
                    ); 
                },
            },
            Quit =>
            {
                item_type => '<StockItem>',
                extra_data => "gtk-quit",
                callback => sub{ Gtk2->main_quit },
            },
            ],
        }, 
        ],
    );

    $view->add_or_pack_child
    (
        parent => $dialog->vbox,
        child => $self->build,
        expand => 1,
    );

    while ( 1 )
    {
        my $response = $dialog->run;

        if ( $response eq 1 )
        {
            print "ok\n";
        }
        else
        {
            return;
        }
    }
}

sub build
{
    my $self = shift;

    my $view = App::UI::Gtk2::View->instance;

    my $main_box = $view->create_box(type => 'v');

    $view->add_page_header(parent => $main_box, text => 'Project Maker');

    my $nb = $view->add_nb
    (
        parent => $main_box,
        expand => 1,
    );
    
    my $cats = $self->_category_hash;
    foreach my $cat ( keys %$cats )
    {
        my $sw = $view->create_sw;
        
        $view->add_or_pack_child
        (
            parent => $sw,
            child => $self->_build_box_for_category($cat),
            expand => 1,
        );
        
        $view->add_page_to_nb
        (
            nb => $nb,
            text => $cat,
            child => $sw, 
        );
    }
    
    return $main_box;
}

sub _category_hash
{
    return 
    {
        'Generate Project' => 
        {
            method => 'build_generate_projects_box',
            options => [qw/ AGP Fasta Size /],
        },
        'Create Projects' => 
        {
            method => 'build_create_projects_box',
            options => [qw/ Acefiles DB /],
        },
        Grab => 
        {
            method => 'build_grab_box',
            options => [ 'Acefiles from DB', 'Contigs From Acefiles', 'Traces', 'Phds' ],
        },
        'AGP Access' => 
        {
            method => 'build_agp_sqlite_access_box',
            options => [ 'Access DB', 'Create AGP DB', 'Add Ace Links to AGP DB' ],
        },
    };
}

sub _build_box_for_category
{
    my ($self, $cat) = @_;

    my $cats = $self->_category_hash;

    my $method = $cats->{$cat}->{method};

    return $self->$method;
}

sub build_grab_box
{
    my $self = shift;

    my $view = App::UI::Gtk2::View->instance;
    
    my $main_box = $view->create_box(type => 'v');
    
    $view->add_cb_crate
    (
        parent => $view->add_frame
        (
            parent => $main_box, text => 'Get Phds Names From'
        ),
    );
    
    $view->add_frame(parent => $main_box, text => 'Phd Source?');

    $view->add_cb_crate
    (
        parent => $view->add_frame
        (
            parent => $main_box, text => 'Where do the Phds Go?'
        ),
    );

    return $main_box;
}

sub build_generate_projects_box
{
    my $self = shift;

    my $view = App::UI::Gtk2::View->instance;
    
    my $main_box = $view->create_box(type => 'v');
    
    $view->add_label(parent => $main_box, text => 'Convert');

    return $main_box;
}

sub build_create_projects_box
{
    my $self = shift;

    my $view = App::UI::Gtk2::View->instance;
    
    my $main_box = $view->create_box(type => 'v');
    
    $view->add_label(parent => $main_box, text => 'Create');

    return $main_box;
}

sub build_agp_sqlite_access_box
{
    my $self = shift;

    my $access_gui = AGP::SQLiteAccessGUI->new();

    die unless $access_gui;
    
    return $access_gui->build;
}

###########################################################################################
###########################################################################################

package Project::Factory;

use strict;
use warnings;

use base qw(Finfo::Object);

use Data::Dumper;
use File::Copy;

sub _attrs
{
    my $self = shift;

    return
    {
        'input_file:r' =>
        {
            type => 'input_file',
            cl_opt => 'in=s',
            desc => 'File of projects',
        },
        'type:r' =>
        {
            type => 'in_list',
            options => [ $self->valid_types ],
            cl_opt => 'type=s',
            desc => 'Type of project to make: ' . join(', ', $self->valid_types),
        },
        '_reader:p' => 
        {
            type => 'inherits_from',
            options => [qw/ Project::Reader /],
        },
        '_writer:p' =>
        {
            type => 'inherits_from',
            options => [qw/ Project::Writer /],
        },
        '_tmp_out_file:p' =>
        {
            type => 'output_file',
        },
    };
}

sub _init
{
    my $self = shift;

    my $reader = Project::Utils->instance->open_reader($self->input_file)
        or return;

    $self->_reader($reader);

    return unless Finfo::Validate->validate
    (
        attr => 'tmp dir',
        value => '/tmp',
        type => 'output_path',
        err_cb => $self,
    );
    
    $self->_tmp_out_file($self->input_file . ".$$.tmp")
        or return;
    my $writer = Project::Utils->instance->open_writer($self->_tmp_out_file)
        or return;

    $self->_writer($writer);

    return 1;
}

sub valid_types
{
    return (qw/ temp gsc gsc_seq_fin /);
}

sub execute
{
    my $self = shift;

    my $method = '_create_' . $self->type . '_project';

    while ( my $project = $self->_reader->next )
    {
        $self->info_msg("Creating $project->{name}");
        $self->$method($project)
            or return;
        $self->_writer->write_one($project)
            or return;
    }

    File::Copy::copy($self->input_file, $self->input_file . '.bak');
    unlink $self->input_file;
    # FIle::Copy::copy doesn't work for the below command, dunno why...
    system (sprintf('cp %s %s',$self->_tmp_out_file, $self->input_file)) and die "$!\n"; 
    unlink $self->_tmp_out_file or die "$!\n";

    unless 
    (
        Finfo::Validate->validate
        (
            attr => 'Updated project file',
            value => $self->input_file,
            type => 'input_file',
            err_cb => $self,
        )
    )
    {
        unlink $self->input_file if -e $self->input_file;
        File::Copy::copy($self->input_file . '.bak', $self->input_file);
        unlink $self->input_file . '.bak';
        return;
    }

    return unlink $self->input_file . '.bak';
}

sub _create_gsc_seq_fin_project
{
    my ($self, $project) = @_;

    my $proj_utils = Project::Utils->instance
        or die;

    return unless $proj_utils->validate_project($project);

    my $gsc_seq_proj = GSC::Sequence::Setup::Finishing::Project->get(name => $project->{name});

    unless ( $gsc_seq_proj )
    {
        return unless $proj_utils->validate_new_seq_name($project->{name});

        $gsc_seq_proj = GSC::Sequence::Setup::Finishing::Project->new
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
            "Could not create GSC::Sequence::Setup::Finishing::Project for $project->{name}"
        )
            and return unless $gsc_seq_proj;

    }

    $proj_utils->create_project_dir_structure( $gsc_seq_proj )
        or return;
    
    #$self->info_msg("Created dir $project->{dir}");

    return $gsc_seq_proj;
}

sub _create_temp_project
{
    my ($self, $project) = @_;

    my $proj_utils = Project::Utils->instance;
    
    return unless $proj_utils->validate_project($project);

    #my $dir = $proj_utils->get_best_projects_dir;
    my $dir = '/gscmnt/815/finishing/projects'; # keep in same dir to track?
    
    return unless -d $dir;
    
    my $tmp_dir = "$dir/tmp-projects";
    
    $self->error_msg("No tmp-projects dir in $dir")
        and return unless -d $tmp_dir;
    
    $project->{dir} = sprintf('%s/%s', $tmp_dir, $project->{name});
    
    mkdir $project->{dir};

    $proj_utils->create_consed_dir_structure($project->{dir})
        or return;

    return 1;
}

sub _create_gsc_project
{
    my ($self, $project) = @_;

    my $proj_utils = Project::Utils->instance;
    
    return unless $proj_utils->validate_project($project);

    my $gsc_proj = GSC::Project->get(name => $project->{name});

    return $gsc_proj if $gsc_proj;
    
    my $ps = GSC::ProcessStep->get
    (
        process_to => 'new project',
        process => 'new project',
    );

    $self->error_msg("Can't get new project process step")
        and return unless $ps;

    my $pse = $ps->execute
    (
        name => $project->{name},
        project_status => 'prefinish_done',
        target => 0,
        purpose => 'finishing',
        group_name => 'crick',
        priority => 0,
    );

    $self->error_msg("Can't execute new project process step for $project->{name}")
        and return unless $pse;

    $gsc_proj = GSC::Project->get(name => $project->{name});

    $self->error_msg("Executed pse, but can't project from db")
        and return unless $project;

    $project->{dir} = $proj_utils->create_project_dir_structure($gsc_proj)
        or return;
    
    #$self->info_msg("Created dir $project->{dir}");

    return $gsc_proj;
}

sub DESTROY
{
    my $self = shift;
    
    #unlink $self->_tmp_out_file if -e $self->_tmp_out_file;
    
    return 1;
}

###########################################################################################
###########################################################################################

package Project::ContigCollector;

use strict;
use warnings;

use base qw(Finfo::Singleton);

use Data::Dumper;
use File::Basename;
use GSC::IO::Assembly::Ace;

sub execute
{
    my ($self, $project, $ace) = @_;

    return unless Project::Utils->instance->validate_project($project);

    return unless Finfo::Validate->validate
    (
        attr => 'ace object to add collected contigs to',
        value => $ace,
        type => 'inherits_from',
        options => [qw/ GSC::IO::Assembly::Ace /],
        err_cb => $self,
    );
    
    $self->info_msg("Collecting contigs for $project->{name}");
    
    foreach my $name ( sort { $self->_sort_contigs } keys %{ $project->{contigs} } )
    {
        my $ctg = $project->{contigs}->{$name};
        if ( exists $ctg->{aceinfo} )
        {
            my $ace_ctg = $self->_grab_contig_from_acefile($name, $ctg)
                or return;
            $ace->add_contig($ace_ctg);# can we check for this??
        }
        elsif ( exists $ctg->{seqinfo} )
        {
            my $seq_ctg = $self->_grab_contig_from_db($name, $ctg)
                or return;
            #TODO convert seq ctg to ace ctg
            my $ace_ctg = GSC::IO::Assembly::Contig->new
            (
                name => $ctg->sequence_item_name
                #etc...
            );
            $self->error_msg("Could not create GSC::IO::Assembly::Contig from GSC::Sequence::Contig")
                and return unless $ace_ctg;
            $ace->add_contig($ace_ctg);# can we check for this??
        }
        else
        {
            $self->error_msg("No source to get contig from for project ($project->{name})");
            return;
        }
    }

    return 1;
}

sub _sort_contigs
{
    $a =~ /Contig(\d+)(?:\.(\d+))*/;
    my $a_super = $1;
    my $a_reg = (defined $2)
    ? $2
    : 0;
    
    $b =~ /Contig(\d+)(?:\.(\d+))*/;
    my $b_super = $1;
    my $b_reg = (defined $2)
    ? $2
    : 0;

    return $a_reg <=> $b_reg if $a_reg and $b_reg;
    
    return $a_super <=> $b_super;
}

sub _grab_contig_from_acefile
{
    my ($self, $new_name, $ctg) = @_;
    
    my ($acefile, $name) = split(/=/, $ctg->{aceinfo});

    return unless Finfo::Validate->validate
    (
        attr => 'ctg name to get',
        value => $name,
        type => 'defined',
        err_cb => $self,
    );

    return unless Finfo::Validate->validate
    (
        attr => 'acefile',
        value => $acefile,
        type => 'input_file',
        err_cb => $self,
    );

    my $tmp_ace;
    if ( $acefile =~ /\.gz$/ )
    {
        # TODO manage better...
        my $ace_base = basename($acefile);
        $tmp_ace = "/tmp/$ace_base";
        unlink $tmp_ace if -e $tmp_ace;
        system "gunzip -c $acefile > $tmp_ace";
        $acefile = $tmp_ace;
        push @{ $self->{_tmp_acefiles} }, $acefile;
    }

    my %ace_p = 
    (
        input_file => $acefile,
        conserve_memory => 1,
    );

    my $ace_dbfile = $acefile . '.db';
    if ( -s $ace_dbfile ) # pass it in, but don't queue to delete
    {
        $ace_p{dbfile} = $ace_dbfile;
    }
    else # queue to delete on destroy
    {
        push @{ $self->{ace_dbfiles} }, $ace_dbfile;
    }

    my $aceobject = GSC::IO::Assembly::Ace->new(%ace_p);
    $self->error_msg("Failed to create GSC::IO::Assembly::Ace for acefile ($acefile)")
        and return unless $aceobject; 

    my $contig = $aceobject->get_contig($name);
    $self->error_msg("Can't get contig ($name) from acefile ($acefile)")
        and return unless $contig;

    my $new_contig;
    if (0)# TODO( exists $ctg->{start} or exists $ctg->{stop} ) 
    {
        my $am = ProjectWorkBench::Model::Ace->new(aceobject => $aceobject);

        my $start = $contig->{start} || 1;
        my $stop = $contig->{stop} || $contig->length; # TODO

        my %reads = 
        (
            map { $_->name => $_ }
            @{ $am->contigs_to_reads(contig_string => sprintf('%s=%dto%d', $name, $start, $stop)) },
        );

        $new_contig = GSC::IO::Assembly::Contig->new(reads => \%reads)
            or die;

        $new_contig->name($new_name);
        $new_contig->calculate_consensus($start, $stop);
        $self->info_msg("Done $new_name");
        $new_contig->calculate_base_segments($start, $stop);
        #$new_contig->tags( $am->contigs_to_base_segments() );
    }
    else
    {
        $new_contig = $contig;
        $new_contig->name($new_name);
        $new_contig->tags([ grep { $_->parent($new_name) } @{ $new_contig->tags } ]);
    }

    # TODO
    if (0)# exists $ctg->{tags} )
    {
        my @tags;
        foreach my $tag_ref ( @{ $ctg->{tags} } )
        {
            push @tags, GSC::IO::Assembly::Tag->new
            (
                parent => $new_name,
                start => $tag_ref->{start} || 1,
                stop => $tag_ref->{stop} || $contig->length,
                type => $tag_ref->{type} || 'comment',
                source => $tag_ref->{source} || 'Project::Maker',
                no_trans => $tag_ref->{no_trans},
            )
                or die;
        }

        $new_contig->tags(\@tags);
    }

    return $new_contig;
}

sub _grab_contig_from_db
{
    my ($self, $new_name, $ctg) = @_;

    my $contig = Project::Utils->instance->get_gsc_seq_item($ctg->{seqinfo})
        or return;

    return unless Project::Utils->instance->validate_new_seq_name($new_name);

    my $new_contig;
    if ( exists $ctg->{start} or exists $ctg->{stop} ) 
    {
        $new_contig = $contig->create_subcontig
        (
            $new_name,
            $ctg->{start} || 1,
            $ctg->{stop} || $contig->length, # TODO
        );
    }
    else
    {
        $new_contig = $contig->copy_contig($new_name);
    }

    # TODO
    if (0)# exists $ctg->{tags} )
    {
        my @tags;
        foreach my $tag_ref ( @{ $ctg->{tags} } )
        {
            push @tags, GSC::Sequence::Tag->new
            (
                parent => $new_name,
                start => $tag_ref->{start} || 1,
                stop => $tag_ref->{stop} || $contig->length,
                type => $tag_ref->{type} || 'comment',
                source => $tag_ref->{source} || 'Project::Maker',
                no_trans => $tag_ref->{no_trans},
            )
                or die;
        }

        $new_contig->tags(\@tags);
    }

    return $new_contig;
}

# Clean up ace tmp files
sub DESTROY
{
    my $self = shift;

    return 1 unless $self->{_tmp_acefiles};
    
    foreach my $tmp_af ( @{ $self->{_tmp_acefiles} } )
    {
        $self->info_msg("Removing $tmp_af"); next;
        unlink $tmp_af if -e $tmp_af;
    }

    foreach my $dbfile ( @{ $self->{_ace dbfiles} } )
    {
        $self->info_msg("Removing $dbfile"); next;
        unlink $dbfile if -e $dbfile;
    }

    return 1;
}


###########################################################################################
###########################################################################################

package Project::Reader;

use strict;
use warnings;

use base qw(Finfo::Reader);

use Data::Dumper;
use IO::File;
use XML::Simple ':strict';

sub _attrs
{
    my $self = shift;

    my $attrs = $self->SUPER::_attrs;
    
    $attrs->{'_xs:p'} = { type => 'inherits_from', options => [qw/ XML::Simple /] };

    return $attrs;
}

sub _init
{
    my $self = shift;

    my $xs = XML::Simple->new
    (
        rootname => 'project',
        KeyAttr => { project => 'name' },
        ForceArray => [qw/ project tags /],
    );
   
    $self->error_msg("Can't create XML::Simple object")
        and return unless $xs;

    $self->_xs($xs)
        or return;

    return $self->SUPER::_init
}

sub _next
{
    my $self = shift;

    my $xml;
    while (1)
    {
        my $line = $self->io->getline;
        unless ( defined $line )
        {
            $self->error_msg("Could not find end of project") if $xml;
            return;
        }
        $xml .= $line;
        last if $line eq "</project>\n";
    }

    my $proj = $self->_xs->XMLin($xml);
    
    return unless Project::Utils->instance->validate_project($proj);
    
    return $proj;
}

###########################################################################################
###########################################################################################

package Project::Writer;

use strict;
use warnings;

use base qw(Finfo::Writer);

use Data::Dumper;
use XML::Simple;

sub _attrs
{
    my $self = shift;

    my $attrs = $self->SUPER::_attrs;
    
    $attrs->{'_xs:p'} = { type => 'inherits_from', options => [qw/ XML::Simple /] };

    return $attrs;
}

sub _init
{
    my $self = shift;

    my $xs = XML::Simple->new
    (
        rootname => 'project',
        KeyAttr => { project => 'name' },
        ForceArray => [qw/ project tags /],
    );

    $self->_xs($xs);
    
    return $self->SUPER::_init
}

sub _write_one
{
    my ($self, $proj) = @_;

    return unless Project::Utils->instance->validate_project($proj);

    my $xml = $self->_xs->XMLout($proj);

    $self->error_msg("Could not create xml for project ref")
        and return unless $xml;
    
    return $self->io->print($xml);
}

###########################################################################################
###########################################################################################

package Project::Namer;

use strict;
use warnings;

use base qw(Finfo::Object);

sub _attrs
{
    my $self = shift;

    my @valid_naming_methods = $self->valid_naming_methods;
    
    return 
    {
        'base_name:r' => 
        {
            type => 'defined',
            cl_opt => 'base=s',
            desc => 'Base name or file for naming'
        },
        'naming_method:o' =>
        {
            type => 'in_list',
            options => \@valid_naming_methods,
            default => $valid_naming_methods[0],
            cl_opt => 'naming-method=s',
            desc => 'Method for naming: iterate, iterate_and replace(replace pattern \'[]\')',
        },
        'start:o' => 
        {
            type => 'positive_integer',
            default => 1,
            cl_opt => 'start=s',
            desc => 'Start number for naming',
        },
        'places:o' => 
        {
            type => 'non_negative_integer',
            cl_opt => 'places=s',
            desc => 'Number of places for naming',
        },
        '_num:p' =>
        {
            type => 'non_negative_integer',
        },
        '_max:p' =>
        {
            type => 'positive_integer',
        },
    };
}

sub valid_naming_methods
{
    return (qw/ iterate iterate_and_replace /); # file /);
}

sub _init
{
    my $self = shift;

    $self->_num( $self->start - 1 );

    if ( defined $self->places )
    {
        # Calculte the maximum # of projects
        my $max = '';
        until (length ($max) == $self->places) { $max .= '9' } 
        $self->_max($max);
    }
    else # no max
    {
        $self->max(0);
    }

    return $self;
}

sub max
{
    return shift->_max;
}

sub next_name
{
    my $self = shift;

    my $method = '_' . $self->naming_method;
    
    return $self->$method;
}

sub _iterate
{
    my $self = shift;

    return $self->base_name . $self->_next_num;
}

sub _iterate_and_replace
{
    my $self = shift;

    my $num = $self->_next_num
        or return;

    my $name = $self->base_name;

    $name =~ s/\[\]/$num/;
    
    return $name;
}

sub _file
{
    # TODO implement??
    die;
    my $self = shift;

    my $line = $self->getline;
    chomp $line;
    
    return $line;
}

sub current_num
{
    my $self = shift;

    if (defined $self->places)
    {
        return $self->_add_zeros( $self->_num );
    }
    else
    {
        return $self->_num;
    }   
}

sub change_base_name_and_reset
{
    my ($self, $new_base) = @_;

    return unless $self->change_base_name($new_base);

    return $self->reset_to_start;
}

sub change_base_name
{
    my ($self, $new_base) = @_;

    return $self->base_name($new_base);
}

sub reset_to_start
{
    my $self = shift;

    return $self->_num( $self->start - 1 );
}

sub _next_num
{
    my $self = shift;
    
    my $num = $self->_num;
    $num++;

    $self->error_msg("Namer has run out of names")
        and return if $self->max and $num > $self->max;

    $self->_num($num);

    return $self->_add_zeros( $num ) if $self->places;

    return $num;
}

sub _add_zeros
{
    my ($self, $num) = @_;

    my $places = $self->places;
    
    my $string = '';
    until (length ($string) == $places - length ($num))
    {
        $string .= '0';
    }
    
    return $string . $num;
}

###########################################################################################
###########################################################################################

package Project::Converter;

use strict;
use warnings;

use base qw(Finfo::Object);

use Bio::SeqIO;
use Data::Dumper;
use IO::File;

sub _attrs
{
    my $self = shift;

    return
    {
        'project_namer:r' => 
        {
            type => 'inherits_from', 
            options => [qw/ Project::Namer /],
        },
        'source_file:r' =>
        {
            type => 'input_file',
            cl_opt => 'src-file=s',
            desc => 'File to read source from',
        },
        'output_file:r' =>
        {
            type => 'output_file',
            cl_opt => 'out=s',
            desc => 'Base file name to write projects to',
        },
        'max_projs_per_file:o' =>
        {
            type => 'positive_integer',
            default => 1000000,
            cl_opt => 'max-projs-per-file=i',
            desc => 'The max number of projects in each output file',
        },
        '_current_proj_count:p' =>
        {
            type => 'non_negative_integer',
            default => 0,
        },
        '_file_namer:p' =>
        {
            type => 'inherits_from',
            options => [qw/ Project::Namer /],
        },
        'output_files:p' =>
        {
            type => 'aryref',
            #type => 'non_empty_aryref',
            default => [],
        },
        'source:r' =>
        {
            type => 'in_list',
            options => [ $self->valid_sources ],
            cl_opt => 'src=s',
            desc => 'Source to convert: ' . join(", ", $self->valid_sources),
        },
        'include_proj_name_in_ctg_name:o' =>
        {
            type => 'defined',
            default => 0,
            cl_opt => 'inc-proj-in-ctg',
            desc => 'This will include the project name in each of the project\'s contig names',
        },
        'aceinfo:o' =>
        {
            type => 'defined',
            cl_opt => 'aceinfo=s',
            desc =>'Acefile pattern, will replace \'[]\' with contig acefile number',
        },
        'pattern:o' =>
        {
            type => 'defined',
            default => '(Contig\d+(\.\d+)?)',
            cl_opt => 'pattern=s',
            desc => 'Pattern to parse for contigs',
        },
        '_writer:p' => 
        {
            type => 'inherits_from',
            options => [qw/ Project::Writer /],
        },
    };
}

sub valid_sources
{
    return (qw/ fasta file /);
}

sub execute
{
    my $self = shift;

    my $method = '_convert_from_' . $self->source;

    $self->$method
        or return;

    return $self->output_files;
}

sub _write_project
{
    my ($self, %project) = @_;

    if ( not $self->_writer 
            or $self->_current_proj_count == $self->max_projs_per_file )
    {
        $self->_current_proj_count(0);
        
        my $outfile = $self->_get_next_file_name
            or return;
        
        my $fh = IO::File->new('>' . $outfile);
        $self->error_msg(sprintf("Can't open file(%s): $!", $outfile))
            and return unless $fh;

        my $writer = Project::Writer->new(io => $fh)
            or return;

        $self->_writer($writer);
    }

    $self->_current_proj_count( $self->_current_proj_count + 1 );
    
    #$self->info_msg("Proj count: ".$self->_current_proj_count." | Max: ".$self->max_projs_per_file);

    return $self->_writer->write_one(\%project);
}

sub _get_next_file_name
{
    my $self = shift;

    unless ( $self->_file_namer )
    {
        my $namer = Project::Namer->new
        (
            base_name => $self->output_file,
            naming_method => 'iterate_and_replace',
        )
            or return;
        $self->_file_namer($namer)
            or return;
    }

    my $file_name = $self->_file_namer->next_name
        or return;
    
    push @{ $self->output_files }, $file_name;
    
    return $file_name;
}

sub _create_ctg_namer
{
    my ($self, $proj_name) = @_;

    my $ctg_base = 'Contig';
    if ( $self->include_proj_name_in_ctg_name )
    {
        $self->error_msg("Need project name to create contig namer")
            and return unless $proj_name;

        $ctg_base = $proj_name . '.Contig';
    }

    return Project::Namer->new(base_name => $ctg_base);
}

sub _parse_line_for_ctgs
{
    my ($self, $line, $ctg_namer) = @_;

    chomp $line;

    return unless $line;

    my $pattern = $self->pattern;

    my $ctgs;
    foreach my $ctg ( $line =~ /$pattern/g ) #(Contig\d+\.\d+)
    {
        my $ctg_params = $self->_create_ctg_params($ctg)
            or return;

        $ctgs->{ $ctg_namer->next_name } = $ctg_params;
    }

    $self->error_msg("No contigs on line: $line")
        and return unless $ctgs;

    return $ctgs;
}

sub _create_ctg_params
{
    my ($self, $ctg) = @_;

    my $p;
    if ( $self->aceinfo )
    {
        my $acenum = Project::Utils->instance->contig_lookup_number($ctg)
            or return;
        my $ace = $self->aceinfo;
        $ace =~ s/\[\]/$acenum/;
        $p->{aceinfo} = "$ace=$ctg";
    }
    else 
    {
        $p->{seqinfo} = $ctg;
    }

    return $p;
}

sub _convert_from_fasta
{
    my $self = shift;

    my $file = $self->source_file;

    my $seqio = Bio::SeqIO->new(-file => $file, -format => 'Fasta');

    $self->error_msg("Could not create Bio::SeqIO for file ($file)")
        and return unless $seqio;
    
    while ( my $seq = $seqio->next_seq )
    {
        my $proj_name = $self->project_namer->next_name
            or return;

        my $ctgs = $self->_parse_line_for_ctgs
        (
            $seq->id, $self->_create_ctg_namer($proj_name),
        )
            or return;

        $self->_write_project
        (
            name => $proj_name, 
            contigs => $ctgs,
        )
            or return;
    }

    return 1;
}

sub _convert_from_file
{
    my $self = shift;

    my $proj_utils = Project::Utils->instance
        or return;

    my $fh = $proj_utils->open_infile($self->source_file)
        or return;

    while ( my $line = $fh->getline )
    {
        my $proj_name = $self->project_namer->next_name
            or die;

        my $ctgs = $self->_parse_line_for_ctgs
        (
            $line, $self->_create_ctg_namer($proj_name),
        )
            or return;

        $self->_write_project
        (
            name => $proj_name, 
            contigs => $ctgs,
        );
    }

    return 1;
}

sub _convert_from_agp
{
    my $self = shift;

    my $proj_utils = Project::Utils->instance
        or return;

    my $fh = $proj_utils->open_infile($self->source_file)
        or return;

    my $agp_reader = AGP::Reader->new(io => $fh)
        or return;

    while ( my $agp = $agp_reader->next )
    {
        # TODO
        my $proj_name = $self->project_namer->next_name
            or die;

        my $ctgs = $self->_parse_line_for_ctgs
        (
            $line, $self->_create_ctg_namer($proj_name),
        )
            or return;

        $self->_write_project
        (
            name => $proj_name, 
            contigs => $ctgs,
        );
    }

    return 1;
}

###########################################################################################
###########################################################################################

package Project::AGPConverter;

use strict;
use warnings;

use base qw(Project::Converter);

use AGP;
use Bio::SeqIO;
use Data::Dumper;
use IO::File;

sub _attrs
{
    my $self = shift;

    my $attrs = $self->SUPER::_attrs;
    
    $attrs->{'agp_dbfile:r'} =
    {
        type => 'input_file',
        cl_opt => 'agp-dbfile=s',
        desc => 'AGP SQLite file',
    };
    $attrs->{'_agp_access:p'} =
    {
        type => 'inherits_from',
        options => [qw/ AGP::SQLiteAccess /],
    };
    
    return $attrs;
}

sub _init
{
    my $self = shift;

    my $agp_access = AGP::SQLiteAccess->new(dbfile => $self->agp_dbfile)
        or return;
    $self->_agp_access($agp_access)
        or return;

    return 1;
}

sub valid_sources
{
    return (qw/ agp agp_fasta /);
}

sub _convert_from_agp
{
    my $self = shift;

    my $file = $self->src_file;
    my $io = IO::File->new("< $file");
    $self->error_msg("Could not open file ($file):\n$!")
        and return unless $io;

    my $reader = AGP::Reader->new
    (
        io => $io,
        return_as_objs => 1,
    )
        or return;

    while ( my $agp = $reader->next )
    {
        #TODO
        $self->_write_project
        (
            {
                name => $self->namer->next_name,
                contigs => {}
            },
        );
    }
    
    return 1;
}

sub _convert_from_agp_fasta
{
    my $self = shift;

    my $file = $self->source_file;
    my $seqio = Bio::SeqIO->new(-file => $file, -format => 'Fasta');

    $self->error_msg("Could not create bio seqio for file ($file)")
        and return unless $seqio;
    
    while ( my $seq = $seqio->next_seq )
    {
        my ($scaff, $start, $stop);
        if ( $seq->id =~ /Location=([\w\d]+)\:(\d+)\-(\d+)/ )
        {
            $scaff = "$1";
            $start = "$2";
            $stop = "$3";
        }

        my (undef, $num) = $self->_agp_access->ctg_location($scaff, $start)
            or return;

        my $ctg = $scaff . '.' . $num;
        my $ctg_params = $self->_create_ctg_params($ctg)
            or return;
        
        $self->_write_project
        (
            {
                name => $self->project_namer->next_name,
                contigs => 
                {
                    # Contig1 => $ctg_params, #TODO new name?
                    $ctg => $ctg_params,
                },
            }
        ) 
            or return;
    }

    return 1;
}

###########################################################################################
###########################################################################################

package Project::Checkout;

use strict;
use warnings;

use base qw(Finfo::Object);

use Compress::Zlib;
use Data::Dumper;
use File::Basename;
use File::Copy;
use Finfo::Validate;
use GSC::IO::Assembly::Ace;
use GSC::IO::Assembly::Ace::Writer;
use GSC::Sequence::Assembly::AceAdaptor;
use IO::File;
use ProjectWorkBench::Model::Ace;
use TraceArchive;
use TraceArchive::Project;

sub _attrs
{
    my $self = shift;

    return
    {
        'input_file:r' =>
        {
            type => 'input_file',
            cl_opt => 'in=s',
            desc => 'File of projects',
        },
        '_reader:p' =>
        {
            type => 'inherits_from',
            options => [qw/ Project::Reader /],
        },
    };
}

sub _init
{
    my $self = shift;

    $self->_reader( Project::Utils->instance->open_reader($self->input_file) )
        or return;

    return 1;
}

sub execute
{
    my $self = shift;

    while ( my $project = $self->_reader->next )
    {
        return unless Project::Utils->instance->create_consed_dir_structure($project->{dir});

        if ( $project->{seq_region_id} )
        {
            $self->_checkout_sequence_region($project)
        }
        else
        {
            $self->_checkout($project);
        }
    }

    return 1;
}

sub _checkout
{
    my ($self, $project) = @_;

    return unless Finfo::Validate->validate
    (
        attr => 'project directory',
        value => $project->{dir},
        type => 'output_path',
        err_cb => $self,
    );
    
    Project::Utils->instance->create_consed_dir_structure($project->{dir})
        or return;
    
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

    Project::ContigCollector->instance->execute($project, $ace)
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
    
    my $acemodel = ProjectWorkBench::Model::Ace->new(aceobject => $ace)
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
        keys %read_names, @{ $self->_get_missed_db_traces }
    );    

    unlink $acefile . '.db' if -e $acefile . '.db';
    
    return 1;
}

sub _checkout_sequence_region
{
    my ($self, $project) = @_;

    my $region = Project::Utils->instance->get_gsc_sequence_item( $project->{seq_region_id} )
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

    $self->_retrieve_traces_from_the_trace_archive($project, @{ $self->_get_missed_db_traces });
    
    return 1;
}

sub _touch_singlets_file_for_acefile
{
    my ($self, $acefile) = @_;

    my $singlets_file = $acefile . '.singlets';

    return 1 if -e $singlets_file;

    system("touch $singlets_file");

    return 1 if -e $singlets_file;
    
    $self->info_msg("Failed to create singlets file for acefile ($acefile)");

    return;
}

sub _export_scfs_and_phds
{ 
    my ($self, $project, $reads) = @_;

    return unless Finfo::Validate->validate
    (
        attr => 'reads to export',
        value => $reads,
        type => 'non_empty_aryref',
        err_cb => $self,
    );

    my $chromat_dir = $project->{dir} . '/chromat_dir';
    my $phd_dir = $project->{dir} . '/phd_dir';

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
            $self->_add_missed_db_traces($read->name);
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

# missed db traces
sub _add_missed_db_traces
{
    my ($self, @trace_names) = @_;

    return push @{ $self->{_missed_db_traces} }, @trace_names;
}

sub _get_missed_db_traces
{
    return delete shift->{_missed_db_traces} || [];
}

# ta
sub _retrieve_traces_from_the_trace_archive
{
    my ($self, $project, @read_names) = @_;

    return 1 unless @read_names;
    
    my $ta = TraceArchive->new
    (
        dir => $project->{dir},
        sources => \@read_names,
    )
        or return;

    my $retrieved_traces = $ta->retrieve
        or return;

    use TraceArchive::Trace;
    
    my $ta_proj = TraceArchive::Project->new
    (
        dir => $project->{dir},
        traces => [ map { TraceArchive::Trace->new(name => $_) } @$retrieved_traces ],
    )
        or return;

    return $ta_proj->execute;
}

# Clean up ace db files
sub DESTROY
{
    my $self = shift;

    foreach my $dbfile ( @{ $self->{_ace_dbfiles} } )
    {
        unlink $dbfile if -e $dbfile;
    }

    return 1;
}

###########################################################################################
###########################################################################################

package Project::Splitter;
# TODO this needs to be tweaked a bit, the projs are greater than the
# target size by the difference of the overlap

use base 'Finfo::Object';

use Data::Dumper;

sub _attrs
{
    return 
    {
        'project_namer:r' =>
        {
            type => 'inherits_from',
            options => [ 'Project::Namer' ],
        },
        'writer:r' =>
        {
            type => 'inherits_from',
            options => [qw/ Project::Writer /],
        },
        'include_proj_name_in_ctg_name:o' =>
        {
            type => 'defined',
            default => 0,
            cl_opt => 'inc-proj-in-ctg',
            desc => 'This will include the project name in each of the project\'s contig names',
        },
        'target_size:o' =>
        {
            type => 'integer_gte',
            default => 1000000,
            options => [ 5000 ],
            cl_opt => 'ts=i',
            desc => 'Target bp size of projects',
        },
        'no_split:o' =>
        {
            type => 'defined',
            default => 0,
            cl_opt =>  'ns',
            desc => 'No Split - don\'t split contigs.  Can\'t use --ov and --gr (flag)',
        },
        # TODO add clopts...
        'overlap:o' => 
        {
            type => 'integer_between',
            default => 2000, 
            options => [ 0, 10000 ],
        },
        'gap_range:o' =>
        {
            type => 'integer_between',
            default => 0,
            options => [ 0, 10000 ],
        },
        'min_size:o' => 
        {
            type => 'non_negative_integer',
            default => 0,
        },
    };
}

sub _init
{
    my $self = shift;

    my $writer = Project::Utils->instance->open_writer($self->output_file)
        or return;
    
    $self->_writer($writer)
        or return;
    
    return 1;
}

sub execute
{
    my $self = shift;

    my $projects;
    my $num = 0;
    while (1)
    {
        my ($contig, $u_start, $u_end, $u_length) = $self->_next_contig
            or last;

        # If new project, set name and size
        unless ( defined $projects->[$num]->{name} )
        {
            $projects->[$num]->{name} = $self->project_namer->next_name
                or return;
            $projects->[$num]->{size} = 0;
            $self->_change_base_name_and_reset_ctg_namer($projects->[$num]->{name})
                or return;
        }

        if ( $self->_should_complete_project($projects->[$num]->{size}, $u_length, $u_end) )
        {
            if ( $self->no_split )
            {
                $self->_add_contig_to_project
                (
                    $projects->[$num], $self->_get_contigs_name($contig), $u_start, $u_end
                )
                    or return;
                $num++;
                next;
            }
            
            my $split_start = $u_start;
            my $split_end = $self->target_size - $projects->[$num]->{size} + $split_start - 1;

            # Adjust the split_end if the split_end would fall w/in
            # the gap_range of the start or end of the contig
            if ($split_end < $self->gap_range)
            {
                $split_end = $self->gap_range;
            }
            elsif ($split_end >= $u_length - $self->gap_range)
            {
                $split_end = $u_length - $self->gap_range;
            }

            # Save The contig, start and end for the next pass
            my $saved_start = ($split_end - $self->overlap + 1 > 1)
            ? $split_end - $self->overlap + 1
            : 1;
            
            # Add the overlap to the split end
            $split_end = ($split_end + $self->overlap < $u_end)
            ? $split_end + $self->overlap
            : $u_end;

            $self->_save_contig($contig, $saved_start, $u_end)
                or return;
            $self->_add_contig_to_project
            (
                $projects->[$num], $self->_get_contigs_name($contig), $split_start, $split_end
            )
                or return;

            # Increment to the next project
            $num++;
        }
        else
        {
            $self->_add_contig_to_project
            (
                $projects->[$num], $self->_get_contigs_name($contig), $u_start, $u_end
            )
                or return;
        }
    }

    $self->error_msg("No projects made")
        and return unless @$projects;
    
    $projects->[0]->{comment} = 'first project';
    $projects->[-1]->{comment} = 'last project';
    
    $self->_writer->write_many($projects)
        or return;
    
    return $projects;
}

sub _next_contig
{
    my $self = shift;

    if ( $self->{_saved_contig} )
    {
        return $self->_get_saved_contig;
    }
    elsif ( $self->{_queued_contig} )
    {
        return $self->_get_queued_contig;
    }

    return;
}

sub _get_queued_contig
{
    my $self = shift;

    my $contig = $self->{_queued_contig};
    
    $self->_queue_contig;
    
    if ($contig)
    {
        my $start = 1;
        my $end = $self->_get_contigs_unpadded_end($contig);
        $self->error_msg("Could not get start for contig: " . $self->_get_contigs_name($contig))
            and return unless $start;
        $self->error_msg("Could not get end for contig: " . $self->_get_contigs_name($contig))
            and return unless $end;
        return ($contig, $start, $end, $end - $start + 1);
    }
    
    return;
}

sub _get_saved_contig
{
    my $self = shift;

    my $contig = $self->{_saved_contig};
    my $start = $self->{_saved_start};
    my $end = $self->{_saved_end};

    $self->{_saved_contig} = undef;
    $self->{_saved_start} = undef;
    $self->{_saved_end} = undef;

    return ($contig, $start, $end, $end - $start + 1);
}

sub _save_contig
{
    my ($self, $contig, $start, $end) = @_;

    $self->{_saved_contig} = $contig;
    $self->{_saved_start} = $start;
    $self->{_saved_end} = $end;

    return 1;
}

sub _should_complete_project
{
    my ($self, $size, $u_length, $u_end) = @_;

    if ($u_length + $size > $self->target_size and $u_length > $self->min_size)
    {
        return 1;
    }

    return;
}

sub _change_base_name_and_reset_ctg_namer
{
    my ($self, $proj_name) = @_;

    my $base_name;
    if ( $self->include_proj_name_in_ctg_name )
    {
        $self->error_msg("No project name to include in contig names")
            and return unless $proj_name;
        $base_name = "$proj_name.Contig";
    }
    else
    {
        $base_name = 'Contig';
    }

    unless ( $self->_ctg_namer )
    {
        $self->_ctg_namer
        (
            Project::Namer->new(base_name => $base_name)
        );
    }
    else
    {
        $self->_ctg_namer->change_base_name_and_reset($base_name);
    }

    return 1;
}

sub _add_contig_to_project
{
    my ($self, $project, $old_name, $start, $stop) = @_;


    $self->error_msg("Missing param to add contig to project:\n" . Dumper(\@_))
        and return unless @_ == 5;
    
    $self->info_msg
    (
        sprintf
        (
            'Adding contig %s (%d to %d) to %s',
            $old_name, $start, $stop, $project->{name}
        )            
    );

    $project->{contigs}->{ $self->_ctg_namer->next_name } = 
    {
        aceinfo => join('=', $self->acefile, $old_name),
        start => $start,
        stop => $stop,
    };

    $project->{size} += $stop - $start + 1;

    return 1;
}

###########################################################################################
###########################################################################################

package Project::AcefileSplitter;

use base qw(Project::Splitter);

use Data::Dumper;
use GSC::IO::Assembly::Ace;

sub _attrs
{
    my $self = shift;

    my $attrs = $self->SUPER::_attrs
        or return;

    $attrs->{'acefile:r'} = 
    {
        type => 'input_file',
        cl_opt => 'af=s',
        desc => 'Acefile to split',
    };
    
    $attrs->{'ace_dbfile:o'} = 
    {
        type => 'input_file',
        cl_opt => 'ace-db=s',
        desc => 'Ace db file, default is <$acefile.db>',
    };
    
    $attrs->{'_ace:p'} = 
    {
        type => 'inherits_from',
        options => [qw/ GSC::IO::Assembly::Ace /],
    };

    $attrs->{'_ctg_namer:p'} = { type => 'defined' };
    $attrs->{'_ctg_names:p'} = { type => 'aryref' };
    
    return $attrs;
}

sub _init
{
    my $self = shift;

    $self->SUPER::_init
        or return;
    
    my %ace_p = ( input_file => $self->acefile );
    if ( $self->ace_dbfile )
    {
        $ace_p{conserve_memory} = 1;
        $ace_p{dbfile} = $self->ace_dbfile;
    }
    elsif ( -s $self->acefile . '.db' )
    {
        $self->ace_dbfile( $self->acefile . '.db' );
        $ace_p{conserve_memory} = 1;
        $ace_p{dbfile} = $self->ace_dbfile;
    }

    my $ace = GSC::IO::Assembly::Ace->new(%ace_p);
    $self->error_msg(sprintf('Can\'t open acefile (%s)', $self->acefile))
        and return unless $ace;

    $self->_ace($ace)
        or return;

    $self->_ctg_names( $ace->get_contig_names )
        or return;

    unless ( $self->_queue_contig )
    {
        $self->error_msg(sprintf('Error queueing ctg for acefile (%s)', $self->acefile));
        return;
    }

    return 1;
}

sub _queue_contig
{
    my $self = shift;

    my @ctg_names = @{ $self->_ctg_names };
    if ( @ctg_names )
    {
        $self->{_queued_contig} = $self->_ace->get_contig( shift @ctg_names );
        $self->_ctg_names(\@ctg_names);
    }
    else
    {
        $self->{_queued_contig} = undef;
    }

    return 1;
}

sub _get_contigs_name
{
    my ($self, $contig) = @_;

    $self->error_msg("Need contig to get name")
        and return unless $contig;
    
    return $contig->name;
}

sub _get_contigs_unpadded_end
{
    my ($self, $contig) = @_;

    $self->error_msg("Need contig to get upadded end")
        and return unless $contig;

    return $contig->base_count;
}


###########################################################################################
###########################################################################################

package Project::SuperContigSplitter;

use strict;
use warnings;

use base qw(Project::Splitter);

sub _attrs
{
    my $self = shift;

    my $attrs = $self->SUPER::_attrs;

    $attrs->{'supercontig:r'} = 
    {
        # TODO change to seq_id or name
        type => 'inherits_from',
        options => [ 'GSC::Sequence::SuperContig' ],
    };
    
    $attrs->{'_ci_done:p'} = 
    {
        type => 'defined',
        default => 0,
    };

    $attrs->{'_contig_iterator:p'} = 
    {
        type => 'defined',
    };

    return $attrs;
}

sub _init
{
    my $self = shift;

    $self->SUPER::_init
        or return;

    my $dbh = GSC::Sequence::Item->dbh;
    $self->error_msg("Can't dbh for seq item table")
        and return unless $dbh;

    my $sth = $dbh->prepare
    (
        sprintf
        (
            'select max(start_position) from sequence_position where parent_seq_id = %d',
            $self->supercontig->seq_id
        )
    );
    $self->error_message( $DBI::errstr )
        and return unless $sth;

    $sth->execute
        or ( $self->error_message( $DBI::errstr ) and return );

    my ($stop_seq_pos) = $sth->fetchrow_array;
    
    my $sc_name = $self->supercontig->sequence_item_name;
    $self->error_msg("Could not get last contig seq pos for $sc_name")
        and return unless defined $stop_seq_pos;
    
    my $ci = GSC::Sequence::ChildIterator->new
    (
        parent_seq_id => $self->supercontig->seq_id,
        start_position => 
        {
            operator => 'between', 
            value => [ 1, $stop_seq_pos ], 
        },
    );

    $self->error_msg("Could create contig iterator for $sc_name")
        and return unless $ci;

    $self->_contig_iterator($ci);
    
    $self->_queue_contig
        or ( $self->error_msg("Error getting first contig for $sc_name") and return );
    
    return 1;
}

sub _queue_contig
{
    my $self = shift;

    unless ( $self->_ci_done )
    {
        $self->{_queued_contig} = $self->_contig_iterator->next;
        $self->_ci_done(1) unless $self->{_queued_contig};
    }
    else
    {
        $self->{_queued_contig} = $self->_contig_iterator->next;
    }

    return 1;
}

sub _get_contigs_name
{
    my ($self, $contig) = @_;

    $self->error_msg("Need contig to get name")
        and return unless $contig;
    
    return $contig->sequence_item_name;
}

sub _get_contigs_unpadded_end
{
    my ($self, $contig) = @_;

    $self->error_msg("Need contig to get upadded end")
        and return unless $contig;
    
    return $contig->get_unpadded_position( $contig->seq_length );
}

###########################################################################################
###########################################################################################

package Project::Utils;

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

sub open_outfile
{
    my ($self, $file) = @_;

    return unless Finfo::Validate->validate
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

    my $fh = $self->open_outfile($file)
        or return;

    return Project::Writer->new(io => $fh);
}

sub open_infile
{
    my ($self, $file) = @_;

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

    return unless Finfo::Validate->validate
    (
        attr => 'project name',
        value => $proj->{name},
        type => 'defined',
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

sub tag_timestamp
{
    # consed timestamp
    #050427:142133
    return time2str('%y%m%d:%H%M%S', time);
}

sub create_project_dir_structure
{
    my ($self, $project) = @_;
    
    return unless Finfo::Validate->validate
    (
        attr => 'project to create best dir',
        value => $project,
        type => 'inherits_from',
        err_cb => $self,
        options => [qw/ GSC::Project GSC::Sequence::Setup::Project::Finishing /],
    );

    my $abs_path = $project->consensus_abs_path;
    if ( $abs_path and -d $abs_path )
    {
        $project->consensus_directory($abs_path);
        $self->create_consed_dir_structure($abs_path)
            or return;
        return 1;
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
    
    $self->create_consed_dir_structure($proj_dir)
        or return;
    
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

###########################################################################################
###########################################################################################

package Project::OptionProcessor;

use strict;
use warnings;

use base qw(Finfo::Object);

use Data::Dumper;
use File::Basename;
use Finfo::CommandLineOptions;
use PP::LSF;

sub _attrs
{
    my $self = shift;

    return
    {
        'process:r' => 
        {
            type => 'in_list',
            options => [ $self->valid_processes ],
            #cl_opts => 'process',
            #desc => 'The process to execute: ' . join(',', $self->valid_processes),
        },
        'options:o' =>
        {
            type => 'non_empty_hashref',
        },
    };
}

# Process and Steps
sub valid_processes
{
    return keys %{ shift->_processes_and_classes };
}

sub _process_classes
{
    my $self = shift;
    
    return $self->_processes_and_classes->{ $self->process };
}

sub _processes_and_classes 
{
    return
    {
        checkout => [qw/ Project::Checkout /], 
        convert => [qw/ Project::Converter Project::Namer /],
        convert_from_agp => [qw/ Project::AGPConverter Project::Namer /],
        create  => [qw/ Project::Factory /],
        split_supercontig  => [qw/ Project::SuperContigSplitter Project::Namer /],
        split_acefile => [qw/ Project::AcefileSplitter Project::Namer /],
    };
}

sub execute
{
    my $self = shift;

    $self->info_msg(sprintf('Processing options for process (%s)', $self->process));
    
    my $method = ( $self->options ) 
    ? '_create_steps_for_' . $self->process
    : '_process_command_line_args';

    return $self->$method;
}

sub _process_command_line_args
{
    my $self = shift;

    $self->info_msg('Processing command line args');
    
    my $clo = Finfo::CommandLineOptions->new
    (
        classes => $self->_process_classes,
        add_q => 1,
        header_msg => 'Usage for ' . $self->process,
    )
        or return;

    my $opts = $clo->get_options
        or return;

    $self->options($opts)
        or return;

    my $method = '_create_steps_for_' . $self->process;

    $self->info_msg('Creating steps');

    return $self->$method;
}

sub _validate_class_options
{
    my $self = shift;

    $self->info_msg('Validating class options');

    foreach my $class ( @{ $self->_process_classes } )
    {
        return unless Finfo::Validate->validate
        (
            attr => "$class options",
            value => $self->options->{$class},
            type => 'non_empty_hashref',
            err_cb => $self,
        );
    }

    return 1;
}

# Split Acefiles
sub _create_steps_for_split_acefile
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    $self->options->{'Project::AcefileSplitter'}->{project_namer} = Project::Namer->new
    (
        %{ $self->options->{'Project::Namer'} } 
    )
        or return;

    return Project::AcefileSplitter->new
    (
        %{ $self->options->{'Project::AcefileSplitter'} },
    );
}

# Convert
sub _create_steps_for_convert
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    $self->options->{'Project::Converter'}->{project_namer} = Project::Namer->new
    (
        %{ $self->options->{'Project::Namer'} } 
    )
        or return;

    return Project::Converter->new
    (
        %{ $self->options->{'Project::Converter'} }
    );
}

sub _create_steps_for_convert_from_agp
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    $self->options->{'Project::AGPConverter'}->{project_namer} = Project::Namer->new
    (
        %{ $self->options->{'Project::Namer'} } 
    )
        or return;

    return Project::AGPConverter->new
    (
        %{ $self->options->{'Project::AGPConverter'} }
    );
}

# Create
sub _create_steps_for_create
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    return Project::Factory->new
    (
        %{ $self->options->{'Project::Factory'} }
    );
}

# Checkout 
sub _create_steps_for_checkout
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    return Project::Checkout->new
    (
        %{ $self->options->{'Project::Checkout'} }
    );
}

###########################################################################################
###########################################################################################

package Project::StepExecutor;

use strict;
use warnings;

use base qw(Finfo::Object);

use Data::Dumper;
use File::Basename;
use Finfo::CommandLineOptions;
use PP::LSF;

sub _attrs
{
    my $self = shift;

    return
    {
        'steps:r' =>
        {
            type => 'non_empty_aryref',
        },
        'params:r' =>
        {
            type => 'non_empty_hashref',
        },
    };
}

sub run
{
    my $self = shift;

    foreach my $step ( @{ $self->steps } )
    {
        $self->error_msg(sprintf('Unsupported step (%s)', $step))
            and return unless $self->can($step);
        $self->info_msg(sprintf('Executing step (%s)', $step));
        $self->$step
            or return;
    }
    
    return 1;
}

sub _execute_af_splitter
{
    my $self = shift;

    #my $params = $self->params;
    my $projects = $self->params->{acefile_splitter}->execute
        or return;

    $self->params->{projects} = $projects;
    
    return $projects;
}

sub _execute_writer
{
    my $self = shift;

    return unless $self->params->{projects};

    return 1 unless $self->params->{writer};
    
    return $self->params->{writer}->write_many( $self->params->{projects} );
}

sub _execute_reader
{
    my $self = shift;

    return unless $self->params->{reader};

    $self->params->{projects} = $self->params->{reader}->all
        or return;

    return 1;
}

sub _collect_contigs_and_create_acefiles
{
    my $self = shift;

    return unless $self->params->{projects};
    return unless $self->params->{dir};
    
    my $collector = Project::ContigCollector->instance;
    
    foreach my $project ( @{ $self->params->{projects} } )
    {
        $self->info_msg("Creating acefile for " . $project->{name});

        my $ace = GSC::IO::Assembly::Ace->new()
            or die;

        my $ctgs = $collector->collect($project)
            or die;

        foreach my $ctg ( @$ctgs )
        {
            $ace->add_contig($ctg);
        }

        $ace->write_file
        (
            output_file => sprintf('%s/%s.fasta.screen.ace', $self->params->{dir}, $project->{name})
        );
    }

    return 1;
}


1;

=pod

=head1 Name

 Project::Maker

=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 Disclaimer

 Copyright (C) 2007 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)


 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/ProjectMaker.pm $
#$Id: ProjectMaker.pm 29849 2007-11-07 18:58:55Z ebelter $
