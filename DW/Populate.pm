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
    my $num_fact_rows_created = $dwp->populate_star_schema;

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


my %star_schema_category_tables = (
    production => {
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
        facts      => [
                        'production_read_fact',
                        'read_fact'
                      ]
    },

    generic => {
        dimensions => [
                        'seq_dim',
                        'source_sample_dim',
                        'run_dim',
                        'archive_project_dim',
                        'processing_dim'
                      ],
        facts      => [
                        'read_fact'
                      ]
    }
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(
        qw(
            read
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
            $self->read_set('');
            $self->read('');
            return ;
        }
        $self->read_set(\@read_sets);
    }

    unless ( defined($self->read) ) {
        my $set = $self->read_set();
        my $read = shift(@{$set});
        $self->read($read);
    }
    
    return 1;
}

sub star_schema_category_for_selected_read {
    my $self = shift;
    my %args = @_;
    
    my $r = $args{'read'} || die "[err] Please specify a read exp!\n";;

    my $fc_id = $r->funding_id();
    my $fc = GSC::FundingCategory->get($fc_id);
    
    if ($fc->pipeline eq 'shotgun sequencing') {
        return 'production';
    } else {
        return 'generic';
    }
}

sub dimensions_for_selected_read {
    my $self = shift;
    my %args = @_;

    my $r = $args{'read'} || die "[err] Please specify a read exp!\n";

    # assess the star-schema-type for this read
    my $ssc = $self->star_schema_category_for_selected_read(read => $r);
    unless ($ssc) {
        die '[err] ' , 'run: ', $self->run(), ' read id: ', $r->id,
            ' Could not determine the proper set of dimension tables to populate.'; 
    }

    if (exists $star_schema_category_tables{$ssc}) {
        my $dimsref = $star_schema_category_tables{$ssc}->{'dimensions'};
        return @{$dimsref};
    } else {
        die "[err] Do not know how to deal with ",
            "star_schema_category |$ssc| \n";
    }
}

sub facts_for_selected_read {
    my $self = shift;
    my %args = @_;
    
    my $r = $args{'read'};

    # assess the star-schema-type for this read
    my $ssc = $self->star_schema_category_for_selected_read(read => $r);
    unless ($ssc) {
        die '[err] ' , 'run: ', $self->run(), ' read id: ', $r->id,
            ' Could not determine the proper set of fact tables to populate.'; 
    }

    if (exists $star_schema_category_tables{$ssc}) {
        my $factsref = $star_schema_category_tables{$ssc}->{'facts'};
        return @{$factsref};
    } else {
        die "[err] Do not know how to deal with ",
            "star_schema_category |$ssc| \n";
    }
}

sub populate_specified_tables_for_selected_read {
    my $self = shift;
    my %args = @_;
    my $class = ref($self) || $self;
    
    my %created_table_objects;

    #initialize and verify passed in parameters
    my $read        = $args{'read'} || die "[err] Please specify a read exp!\n";
    my $table_type  = $args{'table_type'}; # 'facts' or 'dimensions'
    my $table_list  = $args{'tables'};     # arrayref of proper fact or dimension tables
    my $dim_info    = $args{'dimension_info'};
    
    my $tables = $table_list or 
        die '[err] List of ', $table_type, "to populate not specified!\n";
    
    # generate fact and/or dimension classes
    for my $table (@{$tables}) {
        my $table_class_name = $table;
        $table_class_name =~ s/\_(\w)/uc($1)/eg; #convert "table_name" to "ClassDimensionForm"
        $table_class_name =~ s/^(\w)/uc($1)/eg;  #ensure that the first letter is capitalized    
        my $table_class = $class . '::' . $table_class_name;
    
        # create the initial parameters used for the fact or
        # dimension class instantiation    
        my %initial_params;
        if ($table_type eq 'dimensions') {
            %initial_params = (read => $read);
        } elsif ($table_type eq 'facts') {
            %initial_params = (read => $read);
            my @dims = $self->dimensions_for_selected_read(read => $read);
            for my $d (@dims) {
                $initial_params{$d} = $dim_info->{$d} ;            
            }
        } else {
            die "[err] $table_type is not a valid star schema table type!\n";
        }
        
        # create the dimension or fact subclass object
        my $tobj = $table_class->new(%initial_params);
        # derive the non primary key columns 
        $tobj->derive_non_pk_columns();
        # based on the derived non primary key(pk) columns see if row
        # already exists in the datawarehouse star schema
        # otherwise insert the new row and obtain a new pk sequence id
        my $id;
        my $gsc_obj = $tobj->get_or_create_gsc_api_object(
                table_type => $table_type,
                table_name => $table
        );
        $id = $gsc_obj->id();
        my $pk = $tobj->primary_key();
        $tobj->$pk($id);
        $created_table_objects{$table} = {
            pseudo => $tobj,
            gsc    => $gsc_obj
        }
    }
    
    return \%created_table_objects;
}

sub cache_data_for_reads {
    my $self = shift;
    my @re_ids = @_;
    
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
    my $counter = 0;
    
    # ensure that there is at least one read associated with this run
    unless ( defined($self->read) && $self->read() ) {
        warn "\n", '[warn] Did not find any reads associated with this run ',
             $self->run(), ' ...skipping', "\n";
        return 0;
    }

    my @newly_created_dim_objects;
    my @newly_created_fact_objects;

    my $success = eval {
        my $re = $self->read;
        my $set = $self->read_set;
        
        # Fill the cache with things to speed processing up.    
        my @re_ids = map { $_->id } ($re,@$set);
        $self->cache_data_for_reads(@re_ids);
        
        # shortcut for populating 'production' type reads 
        # i.e. (currently reads with funding pipeline of 'shotgun sequencing')
        # take a token read from the run and derive the dimension attributes
        # assume that the dimension attributes are the same for the rest of the 
        # reads associated with the run
        if ($self->star_schema_category_for_selected_read(read => $re) eq 'production') {
            my @dim_tables  = $self->dimensions_for_selected_read(read => $re);
            my @fact_tables = $self->facts_for_selected_read(read => $re);
            # properly populate the dimensions with the token read
            my $dim_obj_href = $self->populate_specified_tables_for_selected_read(
                    read       => $re,
                    table_type => 'dimensions',
                    tables     => \@dim_tables
            );
            push(@newly_created_dim_objects, $dim_obj_href);
            my %dim_info = map { $_ => $dim_obj_href->{$_}->{'pseudo'} } @dim_tables;
            # now populate the fact tables associated with the run
            while($re = $self->read()) {
                my $fact_obj_href = $self->populate_specified_tables_for_selected_read(
                        read       => $re,
                        table_type => 'facts',
                        tables     => \@fact_tables,
                        dimension_info => \%dim_info
                );
                push(@newly_created_fact_objects, $fact_obj_href);
                $counter++;
                # progress to the next read element
                my $r = shift(@{$set});
                if (defined($r) && $r) {
                    $self->read($r);
                } else {
                    $self->read('');
                }
            }
        } else {
            # case for non-production runs --
            # foreach read populate the dimension tables and fact tables individually
            for my $re ($self->read(), @{$set}) {
                my @dim_tables  = $self->dimensions_for_selected_read(read => $re);
                my @fact_tables = $self->facts_for_selected_read(read => $re);

                # properly populate the dimensions 
                my $dim_obj_href = $self->populate_specified_tables_for_selected_read(
                        read       => $re,
                        table_type => 'dimensions',
                        tables     => \@dim_tables
                );
                push(@newly_created_dim_objects, $dim_obj_href);
                my %dim_info = map { $_ => $dim_obj_href->{$_}->{'pseudo'} } @dim_tables;
                # properly populate the fact tables
                my $fact_obj_href = $self->populate_specified_tables_for_selected_read(
                        read       => $re,
                        table_type => 'facts',
                        tables     => \@fact_tables,
                        dimension_info => \%dim_info
                );
                $counter++;
            }
        }

        
        # uncache relevant historical data to speed processing up during backfilling.    
#        $self->uncache_data_for_reads(@re_ids);
        return $counter;
    };

    if ($@) {
        # remove any newly relevant created dimension objects if 
        # had problems with population
        my $err_message = $@;
        warn '[warn] Problems occurred midway with OLAP population...',
             'deleting relevant dimension data associated with this run',
             "\n";
        $self->_remove_dimension_objects(@newly_created_dim_objects);
        die "[err] Failed DW::Populate::populate_star_schema_for_run : ",
            "\n\n", $err_message, "\n\n";
        return;
    } else {
        return $success;
    }
}

sub _remove_dimension_objects {
    my $self = shift;
    my @dim_objects = @_;

    for my $dim_obj_href (@dim_objects) {
        my %dim_info = map { $_ => $dim_obj_href->{$_}->{'pseudo'} } 
                       keys %{$dim_obj_href};
        for my $dim (keys %dim_info) {
            my $dobj = $dim_info{$dim};
            $dobj->delete_entry_from_table(table_type => 'dimensions');
        }
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
