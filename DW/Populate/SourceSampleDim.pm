# P A C K A G E ################################################
package DW::Populate::SourceSampleDim;

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
    ss_id
    organism_name
    dna_resource_prefix
    dna_resource_item_name
    vector
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(@columns);

#database attributes
sub table_name { return 'source_sample_dim' }
sub columns { return @columns; }
sub primary_key { return "ss_id"; }

sub new {
    my $class = shift;
    my $self = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub derive_organism_name {
    my $self = shift;
    
    my $r = $self->read();
    my $dr = $r->get_first_ancestor_with_type('dna resource');
    my $o = GSC::Organism::Taxon->get(legacy_org_id => $dr->org_id) or 
        die "[err] Could not derive the organism_name in: ", 
             ref($self), "\n",
             'via read id: ', $r->id(), "\n";
    return $o->species_name();
}

sub derive_vector {
    my $self = shift;
    
    my $r = $self->read();

    my $obj;
    my $dri = $r->get_first_ancestor_with_type('dna resource item');
    if ( $dri->vl_id() ) {
        $obj = $dri;
    } else {
        my $dr = $r->get_first_ancestor_with_type('dna resource');
        if ( $dr->vl_id() ) {
            $obj = $dr;
        } else {
            # last place to look for...
            my $l = $r->get_first_ancestor_with_type('ligation');
            $obj = $l;
        }
    }

    my $vl = GSC::VectorLinearization->get( $obj->vl_id() );
    if ($vl) {
        my $v = GSC::Vector->get($vl->vec_id);
        return $v->vector_name();
    } else {
        return ;
    }
}

sub derive_dna_resource_prefix {
    my $self = shift;
    
    my $r  = $self->read();
    my $dr = $r->get_first_ancestor_with_type('dna resource');
    return $dr->dna_resource_prefix();
}

sub derive_dna_resource_item_name {
    my $self = shift;
    
    my $r   = $self->read();
    my $dri = $r->get_first_ancestor_with_type('dna resource item');
    return $dri->dna_resource_item_name();
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
