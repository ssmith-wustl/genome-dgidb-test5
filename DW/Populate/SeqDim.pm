# P A C K A G E ################################################
package DW::Populate::SeqDim;

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
    sd_id
    direction
    dye_type
    iteration
    seq_vector
    primer
    seq_brew
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(@columns);

#database attributes
sub table_name { return 'seq_dim' }
sub columns { return @columns; }
sub primary_key { return "sd_id"; }

sub new {
    my $class = shift;
    my $self = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub derive_direction {
    my $self = shift;
    my $r = $self->read();    
    my $sr = GSC::Sequence::Read->get($r->id);
    my $new = $sr->primer_direction;
    return $new;
}

sub derive_dye_type {
    my $self = shift;
    
    my $r = $self->read();
    my $s = $r->get_first_ancestor_with_type('sequenced dna') or return 'EMPTY';
    my $c = GSC::DyeChemistry->get(dc_id => $s->dc_id);
    my $dye_name = $c->dye_name;

    if ($dye_name) {
        return $dye_name;
    } else {
        return 'EMPTY';
    }
}

sub derive_iteration {
    my $self = shift;
    
    my $r = $self->read();
    my $t = $r->get_first_ancestor_with_type('trace');
    my $trace_name = $t->trace_name();
    
    my %extensions=map {($_ => 1)} map {$_->extension_suffix} GSC::TraceNameExtension->get;
    my $regex='\.('.join('|', keys %extensions).')(\d+)';
    
    my ($direction, $iteration) = ($trace_name =~ /$regex/);
    return $iteration;
}

sub derive_seq_vector {
    my $self = shift;
    
    my $r   = $self->read();
    my $s   = $r->get_first_ancestor_with_type('sequenced dna') or return;
    $s->load_vl_id_ancestry or return;

    my $vl_id = $s->sequencing_vl_id or return "EMPTY";
    my $vl = GSC::VectorLinearization->get(vl_id => $vl_id) or return;
    my $v = $vl->get_vector or return;
    my $seq_vector = $v->vector_name;

    return $seq_vector;
}

sub derive_primer {
    my $self = shift;
    
    my $r   = $self->read();
    my $s   = $r->get_first_ancestor_with_type('sequenced dna') or return;
    my $p   = GSC::Primer->get(pri_id => $s->pri_id);
    unless ($p) {
        die "[err] Could not derive a primer for read id: ",
            $r->id, ' (', $r->dna_name, ')', "\n";
    }

    my $primer_name;
    if ($p->primer_type and ($p->primer_type eq 'custom') ) {
        $primer_name = 'custom';
    }
    else {
        $primer_name = $p->primer_name();
    }

    if ($primer_name) {
        return $primer_name;
    } else {
        die "[err] Could not derive the primer name!\n";
    }
}

sub derive_seq_brew {
    my $self = shift;
    
    my $r   = $self->read();
    my $s   = $r->get_first_ancestor_with_type('sequenced dna') or return;
    my $seq_pse = $self->get_pse_type(process_to => 'sequence');
    unless ($seq_pse) {
        print '[warn] Could not derive a sequence pse based on ',
            "\n\t",
            'read : ', $r->id(), "\n";
        return 'EMPTY';    
    }
    my $rup;
    my @rup_items = GSC::ReagentUsedPSE->get( pse_id => $seq_pse->pse_id() );
    if (@rup_items > 1) {
        my @d = GSC::DNA->get(dna_id => [GSC::DNAPSE->get(pse_id => $seq_pse->id)]);
        my @ri = GSC::ReagentInformation->get(barcode => [map {$_->bs_barcode } @rup_items]);
        my @prn = GSC::PrimerReagentName->get(reagent_name => \@ri, pri_id => \@d);
        if (@prn > 1) {
            die "[err] Found multiple GSC::PrimerReagentName instead of just 1 value for : \n",
                "run: ", $r->gel_name, "\n",
                "read id: ", $r->id, "\n",
                "process: sequence ", "\n",
                "pse: ", $seq_pse->id, ' (', $seq_pse->class, ')', "\n",
                "GSC::PrimerReagentName values : ", "\n",
                Data::Dumper::Dumper(@rup_items), "\n";
        } else {
            my $prn = $prn[0];
            return $prn->reagent_name;
        }
    } else {
        $rup = $rup_items[0];
    }
    if ( defined($rup) ) {
        my $ri = GSC::ReagentInformation->get( barcode => $rup->bs_barcode() );
        if ( defined($ri) ) {
            return $ri->reagent_name();
        } else {
            print "\n",
                  '[warn] Could not derive seq brew / ReagentInformation for ', 
                  "\n\t",
                  'read : ', $r->id(), "\n\t",
                  'run  : ', $r->gel_name(), "\n\t",
                  'seq pse id : ', $seq_pse->pse_id(), "\n";
            return 'EMPTY';
        }
    } else {
        print "\n",
              '[warn] Could not derive the seq brew / ReagentUsedPSE for ', "\n\t",
              'read : ', $r->id(), "\n\t", 
              'run  : ', $r->gel_name(), "\n\t", 
              'seq pse id : ', $seq_pse->pse_id(), "\n";
        return 'EMPTY';
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
