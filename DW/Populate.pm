# P A C K A G E ################################################
package DW::Populate;

############################################## S Y N O P S I S #
=head1 NAME

DW::Populate - Population of the OLAP star schema

=head1 SYNOPSIS

    use strict;
    use DW::Populate;

    my $run_name = '1aug05.807pmab2';
    my $dwp = DW::Populate->new(run => $run_name);
    my $num_fact_rows_created = $dwp->populate_star_schema_for_run;

    App::DB->sync_database;
    App::DB->commit;

=head1 DESCRIPTION

DW::Populate is a first generation attempt to provide the ETL 
logic for the population of the OLAP schema. 

=cut
################################################ P R A G M A S #
use warnings;
use strict;

################################################ M O D U L E S #
use DBI;
use GSCApp;
use Data::Dumper;
use Benchmark;
use Class::Accessor::Fast;

use DW::Populate::BaseTable;
use DW::Populate::ProductionReadFact;
use DW::Populate::ReadFact;
use DW::Populate::SeqDim;
use DW::Populate::SourceSampleDim;
use DW::Populate::LibraryCoreDim;
use DW::Populate::RunDim;
use DW::Populate::ProductionDateDim;
use DW::Populate::ProductionMachineDim;
use DW::Populate::ProductionEmployeeDim;
use DW::Populate::ProcessingDim;
use DW::Populate::ArchiveProjectDim;

######################################## I N H E R I T A N C E #
our @ISA = qw(Class::Accessor::Fast);

################################################ G L O B A L S #
my %dw_tables = (
    dimensions => [
                    'seq_dim', 
                    'source_sample_dim', 
                    'library_core_dim', 
                    'run_dim', 
                    'archive_project_dim',
                    'production_date_dim',
                    'production_machine_dim', 
                    'production_employee_dim',
                    'processing_dim'
                  ],
                   
    fact       => [
                    'production_read_fact',
                    'read_fact'
                  ]
);


my %pipeline_based_table_groupings = (
    production => {
        dimensions => [
            'seq_dim',
            'source_sample_dim',
            'library_core_dim',
            'production_date_dim',
            'production_machine_dim',
            'production_employee_dim',
            'processing_dim',
            'archive_project_dim',
            'run_dim'
        ],

        facts => [
            'production_read_fact',
            'read_fact'
        ],

        unique_dimensions_in_run => []    
    },

    library_core_production => {
        dimensions => [
            'seq_dim',
            'source_sample_dim',
            'library_core_dim',
            'production_date_dim',
            'production_machine_dim',
            'production_employee_dim',
            'processing_dim',
            'archive_project_dim',
            'run_dim'
        ],

        facts => [
            'production_read_fact',
            'read_fact'
        ],

        unique_dimensions_in_run => [
            'seq_dim',
            'source_sample_dim',
            'library_core_dim',
            'production_date_dim',
            'production_machine_dim',
            'production_employee_dim',
            'archive_project_dim'
        ]    
    },

    other => {
        dimensions => [
            'seq_dim',
            'source_sample_dim',
            'processing_dim',
            'archive_project_dim',
            'run_dim',
        ],

        facts => [
            'read_fact'
        ],
        
        unique_dimensions_in_run => [
            'seq_dim',
            'source_sample_dim',
            'archive_project_dim'
        ]

    }
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(
        qw(
            barcode
            run
            read_set
        ),
        @{$dw_tables{'dimensions'}},
        @{$dw_tables{'fact'}}
);

sub new {
    my $class = shift;
    my $self  = {@_};
    bless($self, $class);
    $self->_init();
    return $self;
}

sub _init {
    my $self = shift;
    
    unless ( defined($self->run) ) {
        die "Need to specify a run for ", ref($self), "\n";
    }

    unless ( defined($self->read_set) ) {
        my $gel_name = $self->run();
        my @read_sets = GSC::ReadExp->get(gel_name => $gel_name);
        unless (@read_sets >= 1) {
            warn "\n", '[warn] Could not obtain a set of reads for run: ', 
                 $gel_name, "\n";
            $self->read_set([]);
            return ;
        }
        $self->read_set(\@read_sets);
    }

    return 1;
}

sub pipeline_for_selected_run {
    my $self = shift;
    my %args = @_;

    my $run_name = $args{'run'} || $self->run;

    unless($run_name) {
        die "[err] Did not specify a run_name in pipeline_for_selected_run!\n";
    }
    
    my @r = GSC::ReadExp->get(gel_name => $run_name);

    my $fc_id = $r[0]->funding_id();
    my $fc = GSC::FundingCategory->get($fc_id);

    if ($fc->pipeline ne 'shotgun sequencing') {
        return 'other';
    }

    # ensure that this run is not a special "library core" 
    # production run (where all reads are "shotgun sequencing"
    # but consist of reads from various species/dna_resource_prefixes)
    my %dna_resource_prefixes_in_run;
    for my $read (@r) {
        my $dr = $read->get_first_ancestor_with_type('dna resource');
        my $drp = $dr->dna_resource_prefix();
        $dna_resource_prefixes_in_run{$drp} = 1;
        if ( scalar(keys %dna_resource_prefixes_in_run) > 1 ) {
            last;
        }
    }

    if ( scalar(keys %dna_resource_prefixes_in_run) > 1 )  {
        return 'library_core_production';
    }
    else {
        return 'production';
    }
}

sub pipeline_for_selected_read {
    my $self = shift;
    my %args = @_;
    
    my $r = $args{'read'} || die "[err] Please specify a read exp!\n";;

    my $fc_id = $r->funding_id();
    my $fc = GSC::FundingCategory->get($fc_id);

    if ($fc->pipeline eq 'shotgun sequencing') {
        return 'production';
    } else {
        return 'other';
    }
}

sub shared_dimensions_within_run_for_pipeline {
    my $self = shift;
    my %args = @_;
    
    my $pipeline = $args{'pipeline'};

    my @all_dims = $self->all_dimensions_for_selected_pipeline(pipeline => $pipeline);

    my @unique_dims = $self->unique_dimensions_within_run_for_pipeline(pipeline => $pipeline);
    my %uniq_dimensions = map { $_ => 1 } @unique_dims;

    my @shared_dims;
    for my $d (@all_dims) {
        if (not exists $uniq_dimensions{$d}) {
            push(@shared_dims, $d);
        }
    }

    return @shared_dims;
}

sub unique_dimensions_within_run_for_pipeline {
    my $self = shift;
    my %args = @_;
    
    my $pipeline = $args{'pipeline'};

    my $dimsref = $pipeline_based_table_groupings{$pipeline}->{'unique_dimensions_in_run'};
    return @{$dimsref};
}

sub all_dimensions_for_selected_pipeline {
    my $self = shift;
    my %args = @_;

    my $pipeline = $args{'pipeline'};

    unless ($pipeline) {
        die "[err] Need to specify a valid pipeline! \n";
    }

    if (exists $pipeline_based_table_groupings{$pipeline}) {
        my $dimsref = $pipeline_based_table_groupings{$pipeline}->{'dimensions'};
        return @{$dimsref};
    } else {
        die "[err] Do not know which dimensions related with ",
            "pipeline |$pipeline| \n";
    }
}

sub all_facts_for_selected_pipeline {
    my $self = shift;
    my %args = @_;
    
    my $pipeline = $args{'pipeline'};

    unless ($pipeline) {
        die "[err] Need to specify a valid pipeline! \n";
    }

    if (exists $pipeline_based_table_groupings{$pipeline}) {
        my $factsref = $pipeline_based_table_groupings{$pipeline}->{'facts'};
        return @{$factsref};
    } else {
        die "[err] Do not know which facts related with ",
            "pipeline |$pipeline| \n";
    }
}

sub cache_data_for_reads {
    my $self = shift;
    my @re_ids = @_;

    App::Object->status_message('start cache_data_for_reads');
#    print "start caching " . Time::HiRes::time, " ", scalar(App::Object->all_objects_loaded), "\n";
    
    # DNA up-to the template in the most common cases.
    my @sr = GSC::Sequence::Read->get(\@re_ids);
    my @sb = GSC::Sequence::BaseString->get(\@re_ids);
    my @all_dr;
    my @dr = GSC::DNARelationship->get(dna_id => \@re_ids);       # read -> trace
    push @all_dr, @dr;
    @dr = GSC::DNARelationship->get(dna_id => [ map { $_->parent_dna_id } @dr]);        # trace -> seqdna
    push @all_dr, @dr;
    @dr = GSC::DNARelationship->get(dna_id => [ map { $_->parent_dna_id } @dr]);        # seqdna -> ? subclone / template / dri
    push @all_dr, @dr;
    @dr = GSC::DNARelationship->get(dna_id => [ map { $_->parent_dna_id } @dr]);        # ? subclone -> ligation / dri / dr
    push @all_dr, @dr;
    
    # Everything we just loaded will be unloaded later to keep the cache light
    $self->{dna_ids_unload_later} ||= [];
    my $dna_ids_unload_later = $self->{dna_ids_unload_later};
    push @$dna_ids_unload_later, map { $_->dna_id } @all_dr;
    
    # DNA above the sequencing template in the most common cases.
    my @dna = GSC::DNA->get([map { $_->parent_dna_id } @all_dr]); # ligation / dri
    my @last_dna = GSC::DNA->is_loaded(dna_id => [map { $_->parent_dna_id } @dr], _squash_duplicates => 1);
    for my $dna (@last_dna) {
        push @dna, $dna->get_dna_ancestry;
    }
    
    # DNA_PSE
    my @dp = GSC::DNAPSE->get(dna_id => \@dna);
    my @p = GSC::PSE->get(pse_id => \@dp);
    
    # DNA Concentration
    my @dc = GSC::DNAConcentration->get(dna_id => $dna_ids_unload_later);

    # Archives
    my @subclones = grep { $_->class eq 'GSC::Subclone'} @dna;
    if (@subclones) {
        my @arc_ids = map { $_->arc_id } @subclones;
        my @ar = GSC::Archive->get(\@arc_ids);
    }

    App::Object->status_message('stop cache_data_for_reads');
#    print "stop caching " . Time::HiRes::time, " ", scalar(App::Object->all_objects_loaded), "\n";

    return 1;
}

sub uncache_data_for_reads {
    my $self = shift;
#    print "start uncaching " . Time::HiRes::time, " ", scalar(App::Object->all_objects_loaded), "\n";
    my $dna_ids_unload_later = $self->{dna_ids_unload_later};
    my @dr = GSC::DNARelationship->is_loaded(dna_id => $dna_ids_unload_later);
    my @d = GSC::DNA->is_loaded(dna_id => $dna_ids_unload_later);
    my @dp = GSC::DNAPSE->is_loaded(dna_id => $dna_ids_unload_later);
    my @p = GSC::PSE->is_loaded(pse_id => \@dp);

    my @sr = GSC::Sequence::Read->is_loaded(re_id => $dna_ids_unload_later);
    my @sb = GSC::Sequence::BaseString->is_loaded(seq_id => $dna_ids_unload_later);

    # DNA Concentrations
    my @dc = GSC::DNAConcentration->is_loaded(dna_id => $dna_ids_unload_later);
    # Archives
    my @ar;
    my @subclones = grep { $_->class eq 'GSC::Subclone'} @d;
    if (@subclones) {
        my @arc_ids = map { $_->arc_id } @subclones;
        @ar = GSC::Archive->get(\@arc_ids);
    }

    for my $obj (@dr,@d,@dp,@p,@sr,@sb,@dc,@ar) {
        unless ($obj->isa("DeletedObject")) {
            $obj->unload
        }
    }
#    print "stop uncaching " . Time::HiRes::time, " ", scalar(App::Object->all_objects_loaded), "\n";
    return 1;
}

sub populate_star_schema_for_run {
    my $self = shift;
    
    my $reads = $self->read_set;
    my $total_num_reads = scalar @{$reads};

    # ensure that there is at least one read associated with this run
    unless ( defined($total_num_reads) && $total_num_reads >= 1 ) {
        warn "\n", '[warn] Did not find any reads associated with this run ',
             $self->run(), ' ...skipping', "\n";
        return 0;
    }

    my $num_reads_populated = 0;
    my $newly_created_dim_objects;
    my $newly_created_fact_objects;

    # Fill the cache with things to speed processing up.    
    my @re_ids = map { $_->id } (@$reads);
    $self->cache_data_for_reads(@re_ids);

    # for the given reads populate the OLAP tables
    ($num_reads_populated, $newly_created_dim_objects, $newly_created_fact_objects) = 
        $self->populate_dimensions_and_facts_for_reads();
    
    # uncache relevant historical data to speed processing up during backfilling.    
#   $self->uncache_data_for_reads(@re_ids);

    return $num_reads_populated;
}

sub populate_dimensions_and_facts_for_reads {
    my $self = shift;

    my $reads = $self->read_set;
    my $token_read = $reads->[0];
    my @remaining_reads = @{$reads}[1 .. $#{$reads}];

    my $num_reads_populated = 0;
    my @newly_created_dim_objects;
    my @newly_created_fact_objects;


    # assuming that the same pipeline is associated with the rest of reads in the run
    my $pipeline          = $self->pipeline_for_selected_run();
# this approach is no longer taken
#    my $pipeline          = $self->pipeline_for_selected_read(read => $token_read); 
    my @dim_tables        = $self->all_dimensions_for_selected_pipeline(pipeline => $pipeline);
    my @fact_tables       = $self->all_facts_for_selected_pipeline(pipeline => $pipeline);
    my @shared_dimensions = $self->shared_dimensions_within_run_for_pipeline(pipeline => $pipeline);
    my @unique_dimensions = $self->unique_dimensions_within_run_for_pipeline(pipeline => $pipeline);

    App::Object->status_message("The pipeline for run ". $self->run . " : " . $pipeline );

    eval {
        # S H A R E D    D I M E N S I O N S    C A S E
        # take a token read from the run and derive the dimension attributes
        # assume that the dimension attributes are the same for the rest of the 
        # reads associated with the run
        for my $dim (@shared_dimensions) {
            $self->derive_non_pk_table_attributes_for_selected_reads(
                    reads      => [$token_read],
                    table_type => 'dimension',
                    table      => $dim
            );
            # get the primary key values for the objects
            my $new_dim_objects = $self->construct_dimension_ids_for_selected_reads(
                    reads      => [$token_read],
                    table_type => 'dimension',
                    table      => $dim
            );
            if (@{$new_dim_objects}) {
                push(@newly_created_dim_objects, @{$new_dim_objects});
            }
        }

        # assign the dimension objects to the other remaing reads in the set/run
        for my $re (@remaining_reads) {
            for my $dim (@shared_dimensions) {
                $re->{$dim} = $token_read->{$dim};
            }
        }

        # U N I Q U E    D I M E N S I O N S   C A S E
        # derive the dimension attributes for each read in run individually
        for my $dim (@unique_dimensions) {
            $self->derive_non_pk_table_attributes_for_selected_reads(
                    reads      => $reads,
                    table_type => 'dimension',
                    table      => $dim
            );
            # get the primary key values for the objects
            my $new_dim_objects = $self->construct_dimension_ids_for_selected_reads(
                    reads      => $reads,
                    table_type => 'dimension',
                    table      => $dim
            );
            if (@{$new_dim_objects}) {
                push(@newly_created_dim_objects, @{$new_dim_objects});
            }
        }

        # F A C T   C R E A T I O N 
        # now populate the fact tables for the set of reads with all attributes derived
        for my $fact_table (@fact_tables) {
            $self->derive_non_pk_table_attributes_for_selected_reads(
                    reads      => $reads,
                    table_type => 'fact',
                    table      => $fact_table
            );
            my $new_fact_objects = $self->finalize_fact_ids_for_selected_reads(
                    reads       => $reads,
                    table_type  => 'fact',
                    table       => $fact_table
            );
            if (@{$new_fact_objects}) {
                push(@newly_created_fact_objects, @{$new_fact_objects});
            }
        }

        $num_reads_populated = 
            (scalar @newly_created_fact_objects)/(scalar @fact_tables);
    };

    if ($@) {
        # remove any newly relevant created dimension objects if 
        # had problems with population
        my $err_message = $@;
        warn '[warn] Problems occurred midway with OLAP population...',
             'deleting relevant dimension data associated with this run',
             "\n";
        $self->_remove_dimension_objects(@newly_created_dim_objects);
        die "[err] Failed DW::Populate::populate_dimension_and_facts_for_production_reads : ",
            "\n\n", $err_message, "\n\n";
    } else {
        return ($num_reads_populated, \@newly_created_dim_objects, \@newly_created_fact_objects);
    }
} 

sub derive_pseudo_object_class_name_for_table_name {
    my $self = shift;
    my $table_name = shift;

    my $class = ref($self) || $self;

    unless ($table_name) {
        return ;
    }

    my $table_class_name = $table_name;
    #convert "table_name" to "ClassDimensionForm"
    $table_class_name =~ s/\_(\w)/uc($1)/eg; 
    #ensure that the first letter is capitalized    
    $table_class_name =~ s/^(\w)/uc($1)/eg;  
    my $table_class = $class . '::' . $table_class_name;

    return $table_class;
}

sub derive_non_pk_table_attributes_for_selected_reads {
    my $self = shift;
    my %args = @_;

    my $reads = $args{'reads'};
    my $type  = $args{'table_type'};
    my $table = $args{'table'};

    my $table_class = $self->derive_pseudo_object_class_name_for_table_name($table);

    for my $read (@{$reads}) {
        # create the initial parameters used for the fact or
        # dimension pseudo class instantiation    
        my %initial_params;

        $initial_params{read} = $read;

        if ($type eq 'fact') {
            my $pipeline = $self->pipeline_for_selected_read(read => $read);
            my @dims = $self->all_dimensions_for_selected_pipeline(pipeline => $pipeline);
            for my $d (@dims) {
                $initial_params{$d} = $read->{$d} ;            
            }
        }

        # create pseudo object
        my $pobj = $table_class->new(%initial_params);
        # derive the non primary key columns 
        $pobj->derive_non_pk_columns();
        # remove the read associated with the pseudo object
        $pobj->read(undef);
        # assign the pseudo object as a hash key to the original read itself
        $read->{$table} = $pobj;
    }

    return 1;
}

sub construct_dimension_ids_for_selected_reads {
    my $self = shift;

    my %args = @_;

    my $reads = $args{'reads'};
    my $type  = $args{'table_type'};
    my $table = $args{'table'};

    my $table_class = $self->derive_pseudo_object_class_name_for_table_name($table);
    my @objects;

    # collect all the pseudo objects of interest
    for my $read (@{$reads}) {
        my $pobj = $read->{$table};
        push(@objects, $pobj);
    }

    my $gsc_objects = $table_class->get_or_create_specified_gsc_dimension_objects(
            pseudo_objects => \@objects,
            table_type => $type,
            table => $table
    );

    my $pk = $table_class->primary_key;

    my @newly_created_dims;
    my %seen_dim_ids;
    GSC: for my $gsc (@{$gsc_objects}) {
        my $id;
        if (defined $gsc) {
            $id = $gsc->id; 
        }
        else {
            $id = 'undef';
        }
        if (not exists $seen_dim_ids{$id}) { 
            for my $read (@{$reads}) {
                my $pobj = $read->{$table};
                my $pk_value = $pobj->$pk || 'undef';
                if ($pk_value eq $id) {
                    push(@newly_created_dims, { pseudo => $pobj, gsc => $gsc });
                    $seen_dim_ids{$id} = 1;
                    next GSC;
                }
            }
        }
    }

    return \@newly_created_dims;
}

sub finalize_fact_ids_for_selected_reads {
    my $self = shift;

    my %args = @_;

    my $reads = $args{'reads'};
    my $type  = $args{'table_type'};
    my $table = $args{'table'};

    my $table_class = $self->derive_pseudo_object_class_name_for_table_name($table);
    my $gsc_objects = $table_class->create_specified_gsc_fact_objects(
            reads      => $reads,
            table_type => $type,
            table      => $table
    );

    my %gsc_objs = map { $_->id => $_ } @{$gsc_objects};

    my @newly_created_facts;
    for my $read (@{$reads}) {
        push(@newly_created_facts, { pseudo => $read->{$table}, gsc => $gsc_objs{$read->id} });
    }

    return \@newly_created_facts;
}

sub _remove_dimension_objects {
    my $self = shift;
    my @dim_objects = @_;

    my @candidate_pseudo_objects_for_removal;

    for my $obj_href (@dim_objects) {
        my $pobj = $obj_href->{'pseudo'};
        push(@candidate_pseudo_objects_for_removal, $pobj);
    }

    for (@candidate_pseudo_objects_for_removal) {
        $_->delete_entry_from_table(table_type => 'dimensions');
    }
}

sub all_dimensions_tables_in_star_schema {
    my $self  = shift;
    my $class = ref($self) || $self;
    
    my $var = '$' . "${class}::dw_tables{'dimensions'}";
    my $dimensions = eval "return $var";
    return $dimensions;
}

sub all_fact_tables_in_star_schema {
    my $self  = shift;
    my $class = ref($self) || $self;
    
    my $var = '$' . "${class}::dw_tables{'fact'}";

    my $facts = eval "return $var";
    return $facts;
}

# P A C K A G E  L O A D I N G ######################################
1;

__END__

# $Header$
