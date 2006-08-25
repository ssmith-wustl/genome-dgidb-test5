# P A C K A G E ################################################
package DW::Populate::LibraryCoreDim;

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
    lcd_id
    source_dna_name
    source_dna_type
    library_id
    library_number
    fraction_id
    fraction_size
    ligation_id
    ligation_name
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(@columns);

#database attributes
sub table_name { return 'library_core_dim'; }
sub columns { return @columns; }
sub primary_key { return "lcd_id"; }

sub new {
    my $class = shift;
    my $self  = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub derive_source_dna_name {
    my $self = shift;
    
    my $r = $self->read();
    my $base_template = $r->get_base_template;
    
    if ($base_template) {
        return $base_template->dna_name();
    } else {
        print "\n\t[warn] Could not obtain a base_template regarding this gel ",
              "and read(", $r->id(), ")", "\n";
        return ;
    }
}

sub derive_source_dna_type {
    my $self = shift;
    
    my $r = $self->read();
    my $base_template = $r->get_base_template;
    my $clone_type;
    
    if ($base_template) {
        if ($base_template->isa('GSC::Clone') ) {
            $clone_type = $base_template->clone_type();
        } elsif ($base_template->isa('GSC::GenomicDNA') ) {
            $clone_type = 'genome';
        }
    }     

    return $clone_type;
}

sub derive_library_id {
    my $self = shift;
    
    my $r  = $self->read();
    my $cl = $r->get_first_ancestor_with_type('library');
    
    if ($cl) {
        return $cl->cl_id();
    } else {
        print "\n\t[warn] Could not obtain a GSC::CloneLibrary regarding this gel ",
              "and read(",
               $r->id(), ")\n";
        return ;
    }
}

sub derive_library_number {
    my $self = shift;
        
    my $r = $self->read();
    my $library = $r->get_first_ancestor_with_type('library');
    
    if ($library) {
        return $library->library_number();
    } else {
        return ;
    }
}

sub derive_fraction_id {
    my $self = shift;
    
    my $r = $self->read();
    my $f = $r->get_first_ancestor_with_type('fraction');
    
    if ($f) {
        return $f->fra_id();
    } else {
        return ;
    }
}

sub derive_fraction_size {
    my $self = shift;
    
    my $r = $self->read();
    my $f = $r->get_first_ancestor_with_type('fraction');
    if ( defined($f) ) {
        return $f->fraction_name();
    } else {
        return ;
    } 
}

sub derive_ligation_id {
    my $self = shift;
    
    my $r = $self->read();
    
    my $l = $r->get_first_ancestor_with_type('ligation');
    if ( defined($l) ) {
        return $l->lig_id();
    } else {
        print "\n\t[warn] Could not derive the ligation id regarding this gel!\n";
        return ;
    }
}

sub derive_ligation_name {
    my $self = shift;
    
    my $r = $self->read();
    my $l = $r->get_first_ancestor_with_type('ligation');
    if ( defined($l) ) {
        return $l->ligation_name();
    } else {
        return ;
    }
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
        $search_sql = $self->_construct_search_sql_query();
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
        $insert_sql = $self->_construct_insert_sql_query();
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
            sth => $star_delete_sth,
    );

    return $rows;
}
# P A C K A G E  L O A D I N G ######################################
1;

#$Header$
