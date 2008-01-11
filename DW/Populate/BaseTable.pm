# P A C K A G E ################################################
package DW::Populate::BaseTable;

############################################## S Y N O P S I S #
=head1 NAME

DW::Populate::BaseTable - Base Table class for the DW::Populate::TableName classes

=head1 SYNOPSIS

   This module also serves as a base class bin for all the relevant
   logic needed by the DW::Populate::<table> subclasses.

   you shouldn't need to construct these yourself

=head1 DESCRIPTION


=cut
################################################ P R A G M A S #
use warnings;
use strict;

################################################ M O D U L E S #
use GSCApp;
use Data::Dumper;
use Date::Calc qw(Add_Delta_Days);
use Class::Accessor::Fast;
use Time::HiRes qw(gettimeofday tv_interval);

######################################## I N H E R I T A N C E #
our @ISA = qw(Class::Accessor::Fast);

################################################ G L O B A L S #
my $stardbh;  # the 'cloned' olap database handle
my $cloned_star_dbh_initialization = 0;

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(
        qw(
            read
            barcode
          )
);

sub new {
    my $class = shift;
    my $self  = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub init_cloned_star_dbh {
    my $self = shift;
    my $class = ref($self) || $self;

    unless ($cloned_star_dbh_initialization) {
        if (App::DBI->no_commit) {
            $stardbh = GSC::ProductionReadFact->dbh();
        }
        else {
            $stardbh = GSC::ProductionReadFact->dbh()->clone() or 
                die "[err] Could not clone a database handle to GSC::ProductionReadFact \n";
            # enforce ORACLE to accept default timestamps in this format
            my $session = q(alter session set NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS');
            $stardbh->do($session) or 
                die "[err] Could not execute alter session statment: \n $session \n", 
                    $stardbh->errstr(), "\n";
        }
        $cloned_star_dbh_initialization = 1;
    }
    
    return $stardbh;
}

sub can_dimension_table_have_null_pk_id {
    my $class = shift;
    return ;  # FALSE
}

sub create_specified_gsc_fact_objects {
    my $class = shift;
    my %args = @_;

    my $table_type = $args{'table_type'}; # 'facts' or 'dimensions'
    my $table      = $args{'table'}; # in "table_name" form
    my @reads      = @{$args{'reads'}};

    # derive the GSC class name
    my $gsc_class = $class->derive_gsc_class_name_from_pseudo_class;

    # obtain column properties
    my @non_pk_cols = $class->non_pk_columns; 
    my $pk = $class->primary_key;

    # contruct the GSC object
    my @gsc_objects;

    if ($table_type ne 'fact') {
        die "[err] Entered create_gsc_api_fact_objects ",
            "for $table a $table_type!\n";
    } 

    # obtain column properties
    foreach my $read (@reads) {
        my $pseudo_object = $read->{$table};
        my %attributes = map { $_ => $pseudo_object->$_ } @non_pk_cols;
        # contruct the GSC object
        my $gsc;
        my $pk_id = $read->id;
        
        $gsc = $gsc_class->create(%attributes, $pk => $pk_id);
        unless($gsc) {
            die "[err] Could not obtain an api object when creating a ",
                "$gsc_class object with a $pk id of $pk_id \n";
        }
        $pseudo_object->$pk($pk_id);
        push(@gsc_objects, $gsc);
    }

    return \@gsc_objects;
}

sub get_or_create_specified_gsc_dimension_objects {
    my $class=shift;
    my %args = @_;

    my $table_type = $args{'table_type'}; # 'facts' or 'dimensions'
    my $table_name = $args{'table'}; # in "table_name" form
    my @objects    = @{$args{'pseudo_objects'}};

    # derive the GSC class name
    my $gsc_class = $class->derive_gsc_class_name_from_pseudo_class;

    # obtain column properties
    my @non_pk_cols = $class->non_pk_columns; 
    my $pk = $class->primary_key;

    # determine if the dimension table can have a nullable dimension id
    my $is_nullable = $class->can_dimension_table_have_null_pk_id;

    # contruct the GSC object
    my @gsc_objects;

    if ($table_type ne 'dimension') {
        die "[err] Entered get_or_create_gsc_api_dimension_objects ",
            "for $table_name a $table_type!\n";
    }

    # Step 1: See if gsc object already exists
    #         ( or if gsc really needs to be created -- null id case)
    my @nonexistant;
    foreach my $pseudo_object (@objects) {
        my %attributes = map {$_ => $pseudo_object->$_} @non_pk_cols;

        # count the number of undefined attributes
        my $num_undef_attributes = 0;
        for my $col (@non_pk_cols) {
            if (not defined($attributes{$col})) {
                $num_undef_attributes++; 
            }
        }

        my $gsc_object = $gsc_class->get(%attributes);

        # gsc object already exists
        if($gsc_object) {
            $pseudo_object->$pk($gsc_object->id);
            push @gsc_objects, $gsc_object;
        } 

        # specialized null dimension id case -- 
        # all the relevant attributes are null and the table is nullable
        elsif (($num_undef_attributes == scalar @non_pk_cols) and $is_nullable) {
            $pseudo_object->$pk(undef);
            push @gsc_objects, undef;
        }

        # specialized null dimension die case --
        # all the relevant attributes are null and the table is NOT nullable
        elsif (($num_undef_attributes == scalar @non_pk_cols) and not $is_nullable) {
            die "[err] All non pk attributes undef in deriving row for non-nullable table $table_name ! ";
        }

        # a non existant dimension that needs to be created
        else {
            push @nonexistant, $pseudo_object;
        }
    }

    # Step 2: if not exists properly create it and retrieve
    #         the gsc object
    if(@nonexistant) {
        my @ids = $class->single_threaded_table_row_creator(
                %args,
                objects => \@nonexistant
        );
        for my $pseudo_object (@nonexistant) {
            my $gsc_object = $gsc_class->get($pseudo_object->$pk);
            unless ($gsc_object) {
                die "[err] Could not create a gsc object from ref($pseudo_object) : ",
                    "\n", Dumper($pseudo_object), "\n";
            }
            $pseudo_object->$pk($gsc_object->id);
            push @gsc_objects, $gsc_object; 
        }
    }

    return \@gsc_objects;
}

sub derive_gsc_class_name_from_pseudo_class {
    my $self = shift;
    my $class = ref($self) || $self;
    my @class_name_parts = split(/\:\:/, $class);
    my $table_class_name = $class_name_parts[$#class_name_parts];
    my $gsc_class = 'GSC::' . $table_class_name;

    return $gsc_class;
}

sub single_threaded_table_row_creator {
    my $proto=shift;
    my %args = @_;

#    $DB::single = 1;
    my $table_type = $args{'table_type'}; # 'facts' or 'dimensions'
    my $table_name = $args{'table'}; # in "table_name" form

    my @objects;
    if(ref($proto)) {
	    # Called as an object method
        @objects=($proto);
    } else {
	    # Called as a class method--get the objects out of the arguments
	    @objects=@{$args{'objects'}};
    }
    return unless(@objects);

    App::Object->status_message(
            "Entering single_threaded_table_row_creator App::Lock->create". 
            "for table $table_name"
    );
    my $lock;
    if ($table_name ne 'run_dim') {
        my $t0 = [gettimeofday];
        $lock = App::Lock->create(
                mechanism => 'DB_Table',
                resource_id => $table_name,
                block => 1,
                block_sleep => 5,
                max_try => 360
        ); # should block for a max of 30 minutes
        my $app_lock_time_elapsed = tv_interval($t0);    

        unless($lock) {
            die "[err] Could not obtain an App::Lock when attempting ",
                "to lock table: $table_name for data insertion", "\n",
                "(Took $app_lock_time_elapsed seconds before failing to ",
                "receive lock)", "\n";
        }
        App::Object->status_message(
                "Obtained an App::Lock for table $table_name " .
                "( $app_lock_time_elapsed seconds elapsed )"
        );
    }
    else {
        App::Object->status_message("Skipping obtaining an App::Lock for table $table_name")
    }

    my @ids;
    my $num_objects = scalar @objects;
    my $object_counter = 0;
    foreach my $object (@objects) {
        $object_counter++;
        App::Object->status_message("Working on $table_name object $object_counter of $num_objects");
        # ensure that the row does not already exists!
        App::Object->status_message("Performing pre-emptive id search in table $table_name");
        my $id = $object->search_id(%args);    
        if ($id) {
            App::Object->status_message(
                        "Finished with pre-emptive id search in table $table_name" .
                        "and found id $id"
                        );
        } 
        else {
            App::Object->status_message(
                        "Finished with pre-emptive id search in table $table_name" .
                        "and found no primary key id"
                        );
        }

        # perform the actual insertion
        if (! $id) {
            App::Object->status_message("Attempting to insert entry row to table $table_name");
              $id = $object->insert_entry_into_table(%args);
              $object->star_commit;
              App::Object->status_message("commit on table: $table_name");
        }

        push @ids, $id;
        my $pk = $object->primary_key;
        $object->$pk($id);
    }


    # Properly delete App::Lock
    if ($lock) {
        App::Object->status_message("Attempting to delete App::Lock for table $table_name");
        my $t1 = [gettimeofday];
        $lock->delete;
        my $app_lock_delete_time_elapsed = tv_interval($t1);
        App::Object->status_message(
                "Successfully deleted App::Lock for table $table_name " .
                "($app_lock_delete_time_elapsed seconds elapsed)"
        );
    }
    else {
        App::Object->status_message("No App::Lock was used for $table_name insertion...so no lock to delete");
    }

    if (ref($proto)) {
        return $ids[0];
    } 
    else {
        return @ids;
    }
}

sub _setup_star_sth {
    my $self = shift;
    my $class = ref($self) || $self;
    my %args = @_;

    my $sql = $args{'sql'} or die "[err] Need to provide a SQL query argument\n";
    my $purpose = $args{'purpose'} || 'query';

    my $dbh = $self->star_dbh();
    my $sth = $dbh->prepare($sql) or
        die "[err] Problems preparing SQL for $class $purpose:\n",
            $dbh->errstr(), "\n";

    return $sth;        
}

sub _construct_insert_sql_query {
    my $self = shift;
    my %args = @_;

    #collect the database attributes
    my $table_name = $self->table_name();
    my @cols = $self->columns();
    my $pk = $self->primary_key();
    my $schema = $self->schema();

    # construct the insert query
    my @tabbed_cols = map { "\t$_" } @cols;
    my @tabbed_question_marks = map { "\t?" } @cols;
    my $sql = qq| insert into $table_name | . "\n" .
              qq| ( | . "\n" .
              join(",\n", @tabbed_cols) . "\n" .
              qq| ) | . "\n" .
              qq| values | . "\n" .
              qq| ( | . "\n" .
              join(",\n", @tabbed_question_marks) . "\n" .
              qq| ) | . "\n" ;

    return $sql;
}

sub insert_entry_into_table {
    my $self = shift;
    my %args = @_;

    # collect the input params
    my $sql = $args{'sql'} or 
        die '[err] Could not determine the relevant insert query ',
            'for the optimized insert entry for ', ref($self), "\n";
    my $sth = $args{'sth'} or 
        die '[err] Could not obtain a statment handle ',
            'for the optimized insert entry for ', ref($self), "\n";
    
    my $table_type = $args{'table_type'} or
        die '[err] Could not determine the relevant table type ',
            'for the optimized insert entry fro ', ref($self), "\n";
            
    my $special_overrided_attributes_ref = $args{'attributes'}; 

    # collect the database attributes
    my $table_name = $self->table_name();
    my @cols = $self->columns();
    my $pk = $self->primary_key();
    my $schema = $self->schema();
    my @non_pk_cols = $self->non_pk_columns; 

    # get a proper sequence number for the primary key
    my $seq_id;
    if ($table_type eq 'facts') {
        $seq_id = $self->read->re_id();
    } else {
        $seq_id = $self->generate_sequence_id();
    }
    die "[err] Problem obtaining a sequence id for $table_name \n" 
        unless ($seq_id);

    # setup the data to be inserted
    my %attributes = map { $_ => $self->$_ } @non_pk_cols;
    if ($special_overrided_attributes_ref) {
        %attributes = (%attributes, %{$special_overrided_attributes_ref});
    }

    $attributes{$pk} = $seq_id;

    # execute the sql
    my @params = @attributes{@cols};
    my $t0 = [gettimeofday];
    my $rows = $sth->execute(@params);
    my $commit_execute_time_elapsed = tv_interval($t0);
    App::Object->status_message(
            "Time to execute dimension row insert sql on table : $table_name : $commit_execute_time_elapsed seconds"
    );

    unless ($rows == 1) {
        my $error_string = $sth->errstr();
        my $terminate = 0;
        # Perform another search of the id, just in case another parallel 
        # process has not inserted it yet
        my $id = $self->search_id();
        print "[!] Problem with insertion...",
              "searching if there already an id in the database...id: $id\n";
        if ($id) {
            $seq_id = $id;
        } else {
            $terminate = 1;
        }
        # make sure a rollback is issued to resolve any potential
        # exclusive table locks
        $self->star_rollback; 
        if ($terminate) {
            die "[err] Problems inserting row in $table_name:\n", "\n\n", 
                $error_string, "\n\n", Data::Dumper::Dumper(\%attributes), "\n" ;
        }
    }
        
    if ($seq_id) {
        return $seq_id;
    } else {
        return ;
    }
}

sub _construct_delete_sql_query {
    my $self = shift;
    my %args = @_;

    # collect the database attributes
    my $table_name = $self->table_name();
    my @cols = $self->columns();
    my $pk = $self->primary_key();
    my $schema = $self->schema();
    my @non_pk_cols = $self->non_pk_columns; 

    # construct the delete query
    my $head_sql = qq| delete | . "\n" .
                   qq| from   ${schema}.${table_name} | . "\n" .
                   qq| where  | . "\n" ;
    my @delete_cols;
    # properly handle null and non-null cases
    for my $col (@cols) {
        if (defined($self->$col)) {
            push(@delete_cols, "$col = ? \n");
        } else {
            push(@delete_cols, "$col is null \n");
        }
    }

    my $delete_cols = join('and  ', @delete_cols);
    my $sql = $head_sql . $delete_cols;

    return $sql;
}

sub delete_entry_from_table {
    my $self = shift;
    my %args = @_;

    # collect the input params
    my $sql = $args{'sql'} or 
        die '[err] Could not determine the relevant delete query ',
            'for the optimized delete entry for ', ref($self), "\n";
    my $sth = $args{'sth'} or 
        die '[err] Could not obtain a statment handle ',
            'for the optimized delete entry for ', ref($self), "\n";
    
    my $table_type = $args{'table_type'} or
        die '[err] Could not determine the relevant table type ',
            'for the optimized delete entry for ', ref($self), "\n";
            
    my $special_overrided_attributes_ref = $args{'attributes'}; 

    # collect the database attributes
    my $table_name = $self->table_name();
    my @cols = $self->columns();
    my $pk = $self->primary_key();
    my $schema = $self->schema();
    my @non_pk_cols = $self->non_pk_columns; 

    # setup the data to be inserted
    my %attributes;
    my @valid_data_columns;
    for my $col (@cols) {
        if (defined($self->$col)) {
            $attributes{$col} = $self->$col;
            push(@valid_data_columns, $col);
        } 
    }
#    my %attributes = map { $_ => $self->$_ } @cols;
#    if ($special_overrided_attributes_ref) {
#        %attributes = (%attributes, %{$special_overrided_attributes_ref});
#    }

    my $lock = App::Lock->create(
            mechanism => 'DB_Table',
            resource_id => $table_name,
            block => 1,
            block_sleep => 5,
            max_try => 360
    ); # should block for a max of 30 minutes

    unless($lock) {
        die "[err] Could not obtain an App::Lock when attempting ",
            "to lock table: $table_name for data deletion", "\n";
    }

    # attempt to perform the actual deletion
    # execute the sql
    my @params = @attributes{@valid_data_columns};
    my $rows = $sth->execute(@params);

    unless (defined $rows) {
        $rows = 0;
    }

    if ($rows == 1) {
        print "[!] Successful deletion (attempted to delete $rows row) in $table_name:\n", "\n\n",
              Data::Dumper::Dumper(\%attributes), "\n";
        $self->star_commit;
        print 'commit (for deletion) on table: ', $table_name, "\n";
    } else {
        my $error_string = $sth->errstr();
        print "[!] Problem with deletion (attempted to delete $rows rows) in $table_name:\n", "\n\n",
              $error_string, "\n\n", Data::Dumper::Dumper(\%attributes), "\n";
        print 'rollback (for deletion) on table: ', $table_name, "\n";
        $self->star_rollback;      
    }

    $lock->delete;
    return $rows;
}

sub generate_sequence_id {
    my $self = shift;
    
    my $pk = $self->primary_key();
    my $schema = $self->schema();
    
    # setup the sequence generator column 
    # (just the primary key with 'seq' inplace of 'id')
    # NOTE : the sequence generator column for the 
    #        'seq_process_dim' table is a special case
    my $seq_gen_col = $pk;
    if ($self->table_name eq 'seq_process_dim') {
        $seq_gen_col = 'seq_proc_seq';
    } else {
        $seq_gen_col =~ s/id/seq/;
    }
    
    my $sql = "select ${schema}.${seq_gen_col}.nextval from dual";
    
    # obtain a star schema datawarehouse database handle
    my $dbh = $self->star_dbh();
    my ($seq_id) = $dbh->selectrow_array($sql);
    
    return $seq_id;
}

sub _construct_search_sql_query {
    my $self = shift;
    my %args = @_;

    # collect the database attributes
    my $table_name = $self->table_name();
    my @cols = $self->columns();
    my $pk = $self->primary_key();
    my $schema = $self->schema();
    my @non_pk_cols = $self->non_pk_columns; 

    # construct the search query
    my $head_sql = qq| select $pk | . "\n" .
                   qq| from   ${schema}.${table_name} | . "\n" .
                   qq| where  | . "\n" ;
    my @search_cols;
    # properly handle null and non-null cases
    for my $col (@non_pk_cols) {
        if (defined($self->$col)) {
            push(@search_cols, "$col = ? \n");
        } else {
            push(@search_cols, "$col is null \n");
        }
    }
    
#    my @search_cols = map { $_ . " = ? \n" } @non_pk_cols;
    my $search_cols = join('and  ', @search_cols);
    my $sql = $head_sql . $search_cols;

    return $sql;
}

sub search_id {
    my $self = shift;
    my %args = @_;

    # collect the input params
    my $sql = $args{'sql'} or 
        die '[err] Could not determine the relevant search query ',
            'for the optimized search id for ', ref($self), "\n";
    my $sth = $args{'sth'} or 
        die '[err] Could not obtain a statment handle ',
            'for the optimized search id for ', ref($self), "\n";

    my $special_overrided_attributes_ref = $args{'attributes'};        

    # collect the database attributes
    my $table_name = $self->table_name();
    my @cols = $self->columns();
    my $pk = $self->primary_key();
    my $schema = $self->schema();
    my @non_pk_cols = $self->non_pk_columns; 

    # setup the proper search bind params
    my %attributes;
    my @valid_data_columns;
    for my $col (@non_pk_cols) {
        if (defined($self->$col)) {
            $attributes{$col} = $self->$col;
            push(@valid_data_columns, $col);
        }
    }
#    my %attributes = map { $_ => $self->$_ } @non_pk_cols;
#    if ($special_overrided_attributes_ref) {
#        %attributes = (%attributes, %{$special_overrided_attributes_ref});
#    }

    my @params = @attributes{@valid_data_columns};

    $sth->execute(@params) or 
        die "Could not execute statement: \n" , $sth->errstr(), "\n";

    my $idref = $sth->fetchall_arrayref();
    
    # assess the outputs
    if ( @{$idref} > 1 ) {
        my $items = scalar @{$idref};
        die "[err] There are $items rows in $table_name with ",
            "the same attributes\n",
            Data::Dumper::Dumper(\%attributes), "\n", 
            "There should only be ONE \n";
    }

    return $idref->[0]->[0];
}

sub non_pk_columns {
    my $self = shift;
    
    my @cols = $self->columns();
    my $pk = $self->primary_key();
    my @non_pk_cols = grep { $_ ne $pk } @cols;
    
    return @non_pk_cols; 
}

sub derive_non_pk_columns {
    my $self = shift;
    
    my @non_pk_cols = $self->non_pk_columns();
    
    for my $col_name (@non_pk_cols) {
        my $function = 'derive_' . $col_name;
        my $t1 = Time::HiRes::time;
        #print ">>> $function at " . $t1 . "\n";
        my $output   = $self->$function();
        my $elapsed = Time::HiRes::time - $t1;
        #print "\t$col_name " . $elapsed . " for column-value '$output'\n";
        $self->$col_name($output);
    }    
    
}

sub schema { return 'gscuser' } 

sub star_dbh {
    return $stardbh ;
}

sub star_commit {
    my $self = shift;
    my $class = ref($self) || $self;
    my $schema = $class->schema();
    
    if (App::DBI->no_commit) {
        return 1;
    }
    
#    $stardbh->sync_database();
    $stardbh->commit() or 
        die "Could not commit on $schema \n", 
            $stardbh->errstr() , "\n";
}

sub star_rollback {
    my $self = shift;
    my $class = ref($self) || $self;
    
    if (App::DBI->no_commit) {
        return 1;
    }    
    
    my $schema = $class->schema();
    
    $stardbh->rollback() or 
        die "Could not rollback on $schema \n",
            $stardbh->errstr(), "\n";
}

sub remove_timestamp {
    my $self = shift;
    my $datetime = shift;

    my ($sec, $min, $hour, $day, $month, $year)
        = App::Time->datetime_to_numbers($datetime);
        
    # ensure that the granular timestamp is set to 00:00:00
    ($sec, $min, $hour) = (0, 0, 0);
    
    my $new_date = App::Time->numbers_to_datetime(
            $sec, 
            $min, 
            $hour,
            $day, 
            $month, 
            $year
    );
                                                
    return $new_date ; 
}

my %pse_type;
my $previous_read_id_state;
my $analyzed_pse_cutoff_date;
sub get_pse_type {

    my $self = shift;
#    App::Object->status_message('getting pse type');
    my %args = @_;
        
    my $process = $args{'process_to'};

    my $r = $self->read();

    unless (%pse_type) {
        %pse_type = (
                prep => 
                { 
                    dna_type            => 'sequenced dna', 
                    ps_process_to_regex => '^(prep archive|cell lysis)',
                    ps_id_stop          => {},
                },
                pick => 
                {
                    dna_type            => 'sequenced dna',
                    ps_process_to_regex => '^pick',
                    ps_id_stop          => {},
                },
                inoculate => 
                {
                    dna_type            => 'sequenced dna',
                    ps_process_to_regex => '^inoculate',
                    ps_purpose_regex    => '^(Inoculation|Plasmid Production|Automated Production)',
                    ps_id_stop          => {
                                            map { $_->ps_id => 1 }
                                            GSC::ProcessStep->get(process_to => 'pick') 
                                        }
                },
                sequence => 
                {
                    dna_type            => 'sequenced dna',
                    ps_process_to_regex => '^(sequence|create sequenced dna)$',
                    ps_id_stop          => {},
                }, 
                load => 
                {
                    dna_type            => 'trace',
                    ps_process_to_regex => '^(load|load sequenced dna analyzer)',
                    ps_id_stop          => {},
                },
                spec =>
                {
                    dna_type            => 'sequenced dna',
                    ps_process_to_regex => '^spec archive|verify growths',
                    ps_id_stop          => {},
                }
        );
    }

    unless (exists $pse_type{$process}) {
        die '[err] Do not know how to find the pse of process ',
            "'$process'", "\n";
    }

    # get the relevant data types
    my $pse_type_ref = $pse_type{$process};
    my $dna_type  = $pse_type_ref->{'dna_type'};
    my $process_to = $pse_type_ref->{'ps_process_to_regex'};
    my $purpose;
    if (exists $pse_type_ref->{'ps_purpose_regex'}) {
        $purpose = $pse_type_ref->{'ps_purpose_regex'};
    }
    
    # try to find the pse of interest
    my $t1;
    $t1 = Time::HiRes::time;
    my (@pse_ancestry, @pse_ancestry_filtered, @dna_ancestry);
    
    unless ($r->id == $previous_read_id_state) {
        my $pse = $r->get_creation_event;
        $analyzed_pse_cutoff_date = $pse->date_scheduled;
        @pse_ancestry = $pse->get_prior_pses_recurse;
        $previous_read_id_state = $r->id;
    }

    # get/resolve the exact ps_ids
    my $ps_id_hashref = $pse_type_ref->{ps_id_hashref};
    my $ps_id_stop_hashref = $pse_type_ref->{ps_id_stop};
    unless ($ps_id_hashref) {
        $ps_id_hashref = {};
#        App::Object->status_message('resolving ps_ids');
        for my $ps (GSC::ProcessStep->get()) {
            if ($purpose) {
                if ($ps->process_to =~ /$process_to/ &&
                    $ps->purpose =~ /$purpose/    ) {
                    $ps_id_hashref->{$ps->id} = 1;
                }
            } else {
                if ($ps->process_to =~ /$process_to/) {
                    $ps_id_hashref->{$ps->id} = 1;
                }
            }
        }
        $pse_type_ref->{ps_id_hashref} = $ps_id_hashref;
    }
    
    # start with the specified DNA type
    my $dna = $r->get_first_ancestor_with_type($dna_type) or return;
    my @dp = GSC::DNAPSE->get( dna_id => $dna->id() );
    my @pse = map { GSC::PSE->get(pse_id => $_->pse_id) } @dp or return;
#    $DB::single = 1;
    # ensure that one is only going through pses that have occurred before
    # the analyze_traces/xgasp scheduled date
    @pse = grep { App::Time->compare_dates($analyzed_pse_cutoff_date, $_->date_scheduled()) >= 0 } @pse; 
    @pse = sort { $b->pse_id <=> $a->pse_id } @pse;
    my $loop_count = 0;
    while (@pse) {
      $self->status_message('looping on pses');
        for my $p (@pse) {
            if ($ps_id_hashref->{$p->ps_id}) {
                return $p;
            }
            else {
                next;
            }
        }
        @pse = 
            grep { not $ps_id_stop_hashref->{$_->ps_id} }
            map { $_->get_prior_pses } @pse;
        @pse = sort { $b->pse_id <=> $a->pse_id } @pse;
    }
    
    return;
}

sub _setup_oltp_sth {
    my $self = shift;
    my %args = @_;

    my $sql = $args{'sql'} or die "[err] Need to provide a SQL query argument!\n";

    # obtain a OLTP database handle
    my $oltp_dbh = GSC::ReadExp->dbh();
    
    my $oltp_sth = $oltp_dbh->prepare($sql) or 
        die "Could not prepare sql:\n", $oltp_dbh->errstr(), "\n";

    return $oltp_sth;
}

my %current_pse_warning_flag;

sub derive_date {
    my $self = shift;
    my %args = @_;
    my $type = $args{'type'};

    my $r = $self->read();

    my $pse = $self->get_pse_type( process_to => $type );
    unless ($pse) {
        if ($r->id() ne $current_pse_warning_flag{$type}) {
            warn "\n\t[warn] Could not derive the $type pse for ", 
                 'read_id : ', $r->id(), "\n";
            $current_pse_warning_flag{$type} = $r->id();     
        }
        return ;
    }

    my $date = $pse->date_scheduled;
    
    if ($date) {
        if ( $type eq 'load') {
            # Anything loaded before 7:59:59am is attributed
            # to the previous day
            my ( $sec, $min, $hour, $day, $month, $year ) =
              App::Time->datetime_to_numbers($date);
            # strip leading zeros to numbers
            for ($sec, $min, $hour, $day, $month, $year) {
                unless (/^0+$/) {
                    s/^0+//g;
                }
            }
            if ($hour <= 7 && $min <= 59 && $sec <= 59) {
                my $day_offset = -1;
                my ($shift_year, $shift_month, $shift_day) = 
                    Add_Delta_Days($year, $month, $day, $day_offset);
                my $time_shifted_date = App::Time->numbers_to_datetime(
                        $sec,
                        $min,
                        $hour,
                        $shift_day,
                        $shift_month,
                        $shift_year
                );
                $date = $time_shifted_date;
            }
        }
        my $proper_date = $self->remove_timestamp($date);
        return $proper_date;
    } else {
        print "\n[warn] Problems obtaining the $type date for ", "\n",
              "\t", "read : ", $r->id() , "\n",
              "\t", "pse  : ", $pse->id() , "\n";
        return ;
    }
}

sub derive_machine {
    my $self = shift;
    my %args = @_;
    my $type = $args{'type'};

    my $r = $self->read();
    my $pse = $self->get_pse_type( process_to => $type );
    unless ($pse) {
        if ($r->id() ne $current_pse_warning_flag{$type}) {
            my $r = $self->read();
            warn "\n\t[warn] Could not derive the $type pse for ",
                 'read_id : ', $r->id(), "\n";
            $current_pse_warning_flag{$type} = $r->id();     
        }
        return ;
    }

    my ($ei);
    my @pei = GSC::PSEEquipmentInformation->get(pse_id => $pse->id);
    unless (@pei) {
        warn "[warn] Could not get the GSC::PSEEquipmentInformation for :", "\n",
            "pse: ", $pse->id, "\n",
            "read: ", $r->id, "\n",
            "process_to: ", $type, "\n";
        return ;    
    }
    if (@pei > 1) {
        my @ei = GSC::EquipmentInformation->get(barcode => [map {$_->bs_barcode} @pei]);
        my @parent_ei = GSC::EquipmentInformation->get(barcode => [ map {$_->equinf_bs_barcode} @ei]);
        if (@parent_ei != 1) {
            $DB::single = 1;
            if ($type eq 'sequence' and @parent_ei == 0) {
                my @valid_machine = grep { 
                    ($_->barcode eq '0j00mJ' and $_->machine_number == 11 and $_->equipment_description eq 'Biomek') or
                    ($_->barcode eq '0j00mI' and $_->machine_number == 10 and $_->equipment_description eq 'Biomek')  
                } @ei;
                if (@valid_machine == 1) {
                    my $machine_name = $valid_machine[0]->equipment_description . ' ' . $valid_machine[0]->machine_number;
                    App::Object->status_message("Using specialized machine '${machine_name}' exception case for sequence pse: " . $pse->id );
                    print "\n[warn] Specialized machine '${machine_name}' exception case for prep pse: ", $pse->id, "\n";
                    $ei = $valid_machine[0];
                }
                else {
                    die "[err] Found children equipment informations to be of ", scalar @ei, " values", "\n",
                        "And found parent equipment informations to be of ", scalar @parent_ei, " values.", "\n",
                        "Should be just 1 value for the parent equipment informations. ", "\n",
                        "(process : $type) ", "\n",
                        Data::Dumper::Dumper(\@ei), "\n";
                }
            }
            else {
                die "[err] Found parent equipment informations to be of ", scalar @parent_ei, 
                    " values.  Should be just 1. (process : $type) ", "\n",
                    Data::Dumper::Dumper(\@parent_ei), "\n";
            }
        }
        else {
            $ei = $parent_ei[0];
        }
    } else {
        my $pei = $pei[0];
        $ei = GSC::EquipmentInformation->get(barcode => $pei->bs_barcode);
    }
    unless ($ei) {
        die "[err] Could not get the GSC::EquipmentInformation for :", "\n",
            "pse: ", $pse->id, "\n",
            "read: ", $r->id, "\n",
            "process : ", $type, "\n";
    }

    my $machine = $ei->equipment_description . ' ' . $ei->machine_number;
    
    if ($machine) {
        return $machine;
    } else {
        print "\n[warn] Problems deriving the $type machine for ", "\n",
              "\t", "read : ", $r->id() , "\n",
              "\t", "pse  : ", $pse->id() , "\n";
        return ;
    }    
}

sub derive_employee {
    my $self = shift;
    my %args = @_;
    my $type = $args{'type'};

    my $r = $self->read();
    my $pse = $self->get_pse_type( process_to => $type );
    unless ($pse) {
        if ($r->id() ne $current_pse_warning_flag{$type}) {
            warn "\n\t[warn] Could not derive the $type pse for ", 
                 'read_id : ', $r->id(), "\n";
            $current_pse_warning_flag{$type} = $r->id();     
        }
        return ;
    }
    my $e = GSC::EmployeeInfo->get($pse->ei_id);
    if ($e) {
        my $u = GSC::User->get($e->gu_id);
        return $u->unix_login
    } else {
        return ;
    }
}

# P A C K A G E  L O A D I N G ######################################
1;

__END__

# $Header$
