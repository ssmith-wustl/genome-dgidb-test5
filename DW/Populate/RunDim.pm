# P A C K A G E ################################################
package DW::Populate::RunDim;

################################################ P R A G M A S #
use warnings;
use strict;

################################################ M O D U L E S #
use Data::Dumper;
use DW::Populate::BaseTable;

######################################## I N H E R I T A N C E #
#use base qw(DW::Populate);
our @ISA = qw(DW::Populate::BaseTable);

################################################ G L O B A L S #
my @columns = qw(
    run_id
    load_barcode
    run_name
    analyzed_date
    polymer_reagent
    load_order
);

my %month_names = (
        1  => 'jan',
        2  => 'feb',
        3  => 'mar',
        4  => 'apr',
        5  => 'may',
        6  => 'jun',
        7  => 'jul',
        8  => 'aug',
        9  => 'sep',
        10 => 'oct',
        11 => 'nov',
        12 => 'dec'
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(@columns);

#database attributes
sub table_name { return 'run_dim' }
sub columns { return @columns; }
sub primary_key { return "run_id"; }

sub new {
    my $class = shift;
    my $self = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub derive_load_barcode {
    my $self = shift;
    
    if (defined($self->barcode) && $self->barcode) {
        return $self->barcode();
    }
    
    my $load_pse = $self->get_pse_type( process_to => 'load' );
    unless ($load_pse) {
        my $r = $self->read();
        die '[err] Could not derive the load pse for ', "\n",
            "\t", 'read_id : ', $r->id(), "\n";
    }
    
    my $barcode = $load_pse->get_barcodes(content_type => "DNA");
    return $barcode->barcode;
}

sub derive_run_name {
    my $self = shift;
    
    my $r = $self->read();
    
    return $r->gel_name();
}

sub get_date_scheduled {
    my $self = shift;
    
    my $r = $self->read();
    my $gasp_pse = $r->get_creation_event();
    unless ( $gasp_pse->isa('GSC::PSE::Xgasp') || $gasp_pse->isa('GSC::PSE::AnalyzeTraces') ) {
        my @dp = $r->get_dnapse or 
            die '[err] Could not obtain relevant dna pses for read ', $r->id(), "\n";
        for my $dp (@dp) {
            my $pse = $dp->get_pse;
            my $ps = $pse->get_ps;
            if ($ps->process_to =~ /^(xgasp|analyze traces)$/) {
                $gasp_pse = $pse;
            }
        }

        unless ($gasp_pse) {
            die '[err] Could not obtain an proper xgasp pse regarding ', "\n\t",
                'read: ', $r->id(), "\n\t",
                'run : ', $self->run(), "\n";
        }
    }
    
    my $date_scheduled = $gasp_pse->date_scheduled();
    if ($date_scheduled) {
        return $date_scheduled;
    } else {
        die '[err] Could not obtain a xgasp date scheduled for ', "\n\t",
            'read : ', $r->id(), "\n\t",
            'pse  : ', $gasp_pse->pse_id(), "\n\t",
            'run  : ', $self->run(), "\n";
    }
}

sub derive_analyzed_date {
    my $self = shift;
    
    my $datetime = $self->get_date_scheduled();

    my $analyzed_date = $self->remove_timestamp($datetime);
    
    return $analyzed_date ; 
}

sub derive_polymer_reagent {
    my $self = shift;
    
    my $r        = $self->read();
    my $load_pse = $self->get_pse_type(process_to => 'load');
    unless ($load_pse) {
        die '[err] Could not derive a load pse based on ',
            "\n\t",
            'read : ', $r->id(), "\n\t";
    }
    my $rup;
    my @rup_items = GSC::ReagentUsedPSE->get( pse_id => $load_pse->pse_id() );
    if (@rup_items > 1) {
        die "[err] Found multiple GSC::ReagentUsedPSE instead of just 1 value for : \n",
            "run: ", $r->gel_name, "\n",
            "read id: ", $r->id, "\n",
            "process: sequence ", "\n",
            "pse: ", $load_pse->id, ' (', $load_pse->class, ')', "\n",
            "GSC::ReagentUsedPSE values : ", "\n",
            Data::Dumper::Dumper(@rup_items), "\n";
    } else {
        $rup = $rup_items[0];
    }
    if ( defined($rup) ) {
        my $ri = GSC::ReagentInformation->get( barcode => $rup->bs_barcode() );
        if ( defined($ri) ) {
            return $ri->reagent_name();
        } else {
            print "\n", 
                  '[warn] Could not derive polymer reagent / ReagentInformation for ',
                  "\n\t",
                  'read : ', $r->id(), "\n\t",
                  'pse  : ', $load_pse->id(), "\n\t",
                  'run  : ', $self->run(), "\n";
            return 'EMPTY';
        }
    } else {
        print "\n",
              '[warn] Could not derive the polymer reagent / ReagentUsedPSE for ',
              "\n\t",
              'read : ', $r->id(), "\n\t", 
              'pse  : ', $load_pse->id(), "\n\t",
              'run  : ', $self->run(), "\n\t"; 
        return 'EMPTY';
    }
}

sub derive_load_order {
    my $self = shift;
    
    my $r = $self->read();
    my $gel_name = $r->gel_name();
    
    my ($time_period, $load_order, $quadrant) =
        $gel_name =~ /^\d+\w+\d{2}\.\d+(am|pm)(\w)(\w+\d+)$/;
        
    return $load_order;
}

my $star_search_sth;
my $search_sql;
# This method is subclass for further hard coding and optimization speed
# that is useful during backfilling
sub search_id {
    my $self = shift;
    my %args = @_;

    my $potential_sql_query = $self->_construct_search_sql_query();

    unless ($star_search_sth && ($potential_sql_query eq $search_sql) ) {
        # setup the statement handle
        $search_sql = $potential_sql_query;
        $star_search_sth = $self->_setup_star_sth(
                sql => $search_sql, 
                purpose => 'search'
        );
    }

    my $id = $self->SUPER::search_id(
            %args, 
            sql => $search_sql, 
            sth => $star_search_sth
    );

    return $id;
}

my $star_insert_sth;
my $insert_sql;
# This method is subclass for further hard coding and optimization speed
# that is useful during backfilling
sub insert_entry_into_table {
    my $self = shift;
    my %args = @_;

    # ensure that the run_dim table is properly cleaned up for
    # analyze traces
    $self->cleanup_run_dim_table_entry(%args);

    my $potential_sql_query = $self->_construct_insert_sql_query();

    unless ($star_insert_sth && ($potential_sql_query eq $insert_sql) ) {
        # setup the statment handle
        $insert_sql = $potential_sql_query;
        $star_insert_sth = $self->_setup_star_sth(
                sql => $insert_sql, 
                purpose => 'insert'
        );
    }

    my $id = $self->SUPER::insert_entry_into_table(
            %args, 
            sql => $insert_sql, 
            sth => $star_insert_sth
    );

    return $id;
}

# This method is being added to take care of the observed run_dim
# unique constraint problem cases occuring in analyze traces.  
# This problem occurs when a run_dim row entry get made during 
# the population process, but a sync_database fails during 
# the commiting of the fact table data towards the end of analyze 
# traces.  If the run gets re-submitted afterwards, on a different
# day, a unique constraint occurs due to a row having a similiar
# run_name information, but differing analyzed_date information
my $special_run_delete_sth;
my $special_run_delete_sql;
sub cleanup_run_dim_table_entry {
    my $self = shift;
    my %args = @_;

    my $attributes_href = $args{'attributes'};

    my ($run_name, 
        $polymer_reagent,
        $load_barcode, 
        $load_order) = 
        @{$attributes_href}{
            'run_name',
            'polymer_reagent',
            'load_barcode',
            'load_order'
        } ;
    
    # Check if there already exists a similiar kind of run_dim row
    my @current_run_dim_rows = GSC::RunDim->get(
            run_name => $run_name,
            polymer_reagent => $polymer_reagent,
            load_barcode => $load_barcode,
            load_order => $load_order
    );

    if (@current_run_dim_rows == 1) {
        # Need to ensure that this run_id already does not have 
        # associated facts in the fact tables
        my $rd_id = $current_run_dim_rows[0]->id;
        my @current_rf = GSC::ReadFact->get(run_id => $rd_id);
        my @current_prf = GSC::ProductionReadFact->get(run_id => $rd_id);

        # If there are no associated facts with this id, then
        # go ahead and delete the current relevant run_dim row;
        if ( (@current_rf == 0) and (@current_prf == 0) ) {
            warn '[warn] Found a run id with current relevant run ',
                 'information already in the run table, ',
                 'but with no relevant facts attached:', "\n", 
                 Data::Dumper::Dumper(@current_run_dim_rows), "\n";
            print "Attempting to delete this particular run_dim row \n";     
            $special_run_delete_sql = '
                delete from run_dim 
                where  run_id = ?
                and    run_name = ?
                and    polymer_reagent = ?
                and    load_barcode = ?
                and    load_order = ?
            ';
            $special_run_delete_sth = $self->_setup_star_sth(
                    sql => $special_run_delete_sql, 
                    purpose => 'delete'
            );

            # A lock should have been created for this table 
            # beforehand in the call to 
            # DW::Populate::BaseTable::single_threaded_table_row_creator
            # which invokes 
            # DW::Populate::RunDim::insert_entry_into_table, 
            # which invokes this special method

            # attempt to perform the actual deletion
            # execute the sql
            my $rows = $special_run_delete_sth->execute(
                    $rd_id, 
                    $run_name, 
                    $polymer_reagent, 
                    $load_barcode, 
                    $load_order
            );

            unless (defined $rows) {
                $rows = 0;
            }

            # check on the outcome of the deletion
            if ($rows == 1) {
                print "[!] Successful deletion of run_dim row:\n", "\n\n",
                      "run_id => $rd_id ", "\n",
                      "run_name => $run_name ", "\n",
                      "polymer_reagent => $polymer_reagent ", "\n",
                      "load_barcode => $load_barcode ", "\n",
                      "load_order => $load_order ", "\n";
                $self->star_commit;
                print 'commit (for deletion) on table: run_dim', "\n";
            } else {
                my $error_string = $special_run_delete_sth->errstr();
                print "[!] Problem with deletion of run_dim row (deleteing $rows rows):\n", "\n\n",
                      $error_string, "\n\n", 
                      "run_id => $rd_id ", "\n",
                      "run_name => $run_name ", "\n",
                      "polymer_reagent => $polymer_reagent ", "\n",
                      "load_barcode => $load_barcode ", "\n",
                      "load_order => $load_order ", "\n";
                print 'rollback (for deletion) on table: run_dim', "\n";
                $self->star_rollback;      
            }

            return $rows;
        } else {
            # There are facts associated with this run
            # just issue a warning and return undef
            warn '[warn] Found a run id ', "(run_id: $rd_id) ", 
                 'with current relevant run ',
                 'information already in the run table, ',
                 'but WITH RELEVANT FACTS ATTACHED:', "\n",
                 'This could be problematic!', "\n"; 
            print "Skipping to deletion of this particular run_dim row \n";     
            return ;
        }
    } elsif (@current_run_dim_rows > 1) {
        # Problem...this should not occur
        die '[err] There are multiple (', scalar @current_run_dim_rows, 
            ' rows) lines in the run_dim ',
            'table with the following attributes :', "\n",
            "run_name => $run_name ", "\n",
            "polymer_reagent => $polymer_reagent ", "\n",
            "load_barcode => $load_barcode ", "\n",
            "load_order => $load_order ", "\n",
            'This should not be occuring!', "\n";
    } else {
        # There is no run information already in the run_dim
        # nothing more to do here... zero rows changed
        return 0;
    }
    
}

my $delete_sql;
my $star_delete_sth;
# This method is subclass for further hard coding and optimization speed
# that is useful during backfilling
sub delete_entry_from_table {
    my $self = shift;
    my %args = @_;

    my $potential_sql_query = $self->_construct_delete_sql_query();

    unless ($star_delete_sth && ($potential_sql_query eq $delete_sql) ) {
        # setup the statment handle
        $delete_sql = $potential_sql_query;
        $star_delete_sth = $self->_setup_star_sth(
                sql => $delete_sql, 
                purpose => 'delete'
        );
    }

    my $rows = $self->SUPER::delete_entry_from_table(
            %args, 
            sql => $delete_sql, 
            sth => $star_delete_sth
    );

    return $rows;
}

# P A C K A G E  L O A D I N G ######################################
1;

#$Header$
