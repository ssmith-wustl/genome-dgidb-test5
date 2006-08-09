# P A C K A G E ################################################
package DW::Populate::ProductionDateDim;

################################################ P R A G M A S #
use warnings;
use strict;

################################################ M O D U L E S #
use Data::Dumper;
use DW::Populate::BaseTable;

######################################## I N H E R I T A N C E #
# use base qw(DW::Populate);
our @ISA = qw(DW::Populate::BaseTable);

################################################ G L O B A L S #
my @columns = qw(
    pdd_id
    seq_date
    load_date
    pick_date
    prep_date
    inoc_date
    spec_date
    analyzed_date
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(@columns);

#database attributes
sub table_name { return 'production_date_dim' }
sub columns { return @columns; }
sub primary_key { return "pdd_id"; }

sub new {
    my $class = shift;
    my $self  = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub derive_seq_date {
    my $self = shift;

    my $sequence_date = $self->derive_date( type => 'sequence');
    return $sequence_date;
}

sub derive_pick_date {
    my $self = shift;

    my $pick_date = $self->derive_date( type => 'pick');
    return $pick_date;
}

sub derive_prep_date {
    my $self = shift;

    my $prep_date = $self->derive_date( type => 'prep');
    return $prep_date;
}

sub derive_inoc_date {
    my $self = shift;
    
    my $inoc_date = $self->derive_date( type => 'inoculate');
    return $inoc_date;
}

sub derive_spec_date {
    my $self = shift;
    
    my $spec_date = $self->derive_date( type => 'spec');
    return $spec_date;
}

sub derive_load_date {
    my $self = shift;
    
    my $load_date = $self->derive_date( type => 'load');
    return $load_date;
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

my $star_search_sth;
my $search_sql;
# This method is subclass for further hard coding and optimization speed
# that is useful during backfilling
sub search_id {
    my $self = shift;
    my %args = @_;

    my $potential_sql_query = $self->_construct_search_sql_query();

    unless ($star_search_sth) {
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

    my $potential_sql_query = $self->_construct_insert_sql_query();

    unless ($star_insert_sth) {
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
