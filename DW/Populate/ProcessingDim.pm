# P A C K A G E ################################################
package DW::Populate::ProcessingDim;


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
    proc_id
    load_date
    analyzed_date
    load_machine
    load_group
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(@columns);

#database attributes
sub table_name { return 'processing_dim' }
sub columns { return @columns; }
sub primary_key { return "proc_id"; }

sub new {
    my $class = shift;
    my $self  = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub derive_load_date {
    my $self = shift;
    
    my $load_date = $self->derive_date( type => 'load');
    return $load_date;
}

sub derive_analyzed_date {
    my $self = shift;
    
    my $datetime = $self->get_date_scheduled();

    my $analyzed_date = $self->remove_timestamp($datetime);
    
    return $analyzed_date ; 
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

sub derive_load_machine {
    my $self = shift;
    
    my $load_machine = $self->derive_machine( type => 'load');
    return $load_machine;
}

sub derive_load_group {
    my $self = shift;
    
    my $r = $self->read();

    my $pse = $self->get_pse_type( process_to => 'load' );
    unless ($pse) {
        die "[err] Could not derive the load pse for ",
            'read_id : ', $r->id(), "\n";
    }

    my ($ei);
    my @pei = GSC::PSEEquipmentInformation->get(pse_id => $pse->id);
    unless (@pei) {
        warn "[warn] Could not get the GSC::PSEEquipmentInformation for ",
             "deriving the load group:", "\n",
             "pse: ", $pse->id, "\n",
             "read: ", $r->id, "\n",
             "process_to: load ", "\n";
        return ;    
    }
    if (@pei > 1) {
        my @ei = GSC::EquipmentInformation->get(barcode => [map {$_->bs_barcode} @pei]);
        my @parent_ei = GSC::EquipmentInformation->get(barcode => [ map {$_->equinf_bs_barcode} @ei]);
        unless (@parent_ei == 1) {
            die "[err] Found parent equipment informations for deriving the load group to be of ", scalar @parent_ei, 
                " values.  Should be just 1.", "\n",
                Data::Dumper::Dumper(\@parent_ei), "\n";
        }
        $ei = $parent_ei[0];
    } else {
        my $pei = $pei[0];
        $ei = GSC::EquipmentInformation->get(barcode => $pei->bs_barcode);
    }
    unless ($ei) {
        die "[err] Could not get the GSC::EquipmentInformation for ",
            "deriving the load group:", "\n",
            "pse: ", $pse->id, "\n",
            "read: ", $r->id, "\n",
            "process_to: load ", "\n";
    }

    my $load_group = $ei->group_name;

    return $load_group;
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
