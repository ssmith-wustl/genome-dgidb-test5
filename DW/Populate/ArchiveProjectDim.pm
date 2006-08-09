# P A C K A G E ################################################
package DW::Populate::ArchiveProjectDim;

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
    ap_id
    archive
    archive_group
    project_name
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(@columns);

#database attributes
sub table_name { return 'archive_project_dim' }
sub columns { return @columns; }
sub primary_key { return "ap_id"; }

sub new {
    my $class = shift;
    my $self = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub derive_archive {
    my $self = shift;
    
    my $r = $self->read();
    my $s = $r->get_first_ancestor_with_type('subclone');

    my $archive;
    if ($s) {
        $archive = GSC::Archive->get( $s->arc_id() );
    }

    if ($archive) {
        return $archive->archive_number();
    } else {
        my $r = $self->read();
        my $dri = $r->get_first_ancestor_with_type('dna resource item');
        return $dri->dna_resource_item_name();
    }
}

sub derive_archive_group {
    my $self = shift;

    my $r = $self->read();
    my $s = $r->get_first_ancestor_with_type('subclone');
    
    my $archive;
    if ($s) {
        $archive = GSC::Archive->get( $s->arc_id() );
    }

    if ($archive) {
        return $archive->group_name();
    } else {
        return 'EMPTY' ;
    }
}

sub derive_project_name {
    my $self = shift;
    
    my $r = $self->read();
    my $t = $r->get_first_ancestor_with_type('trace');
    my $p = GSC::Project->get(project_id => $t->project_id) or 
        die "[err] Could not derive the project_name in: ", 
             ref($self), "\n",
             'via trace id: ', $t->id(), "\n";
    return $p->name();
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
