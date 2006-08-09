# P A C K A G E ################################################
package DW::Populate::ReadFact;

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
    read_id
    sd_id
    ss_id
    run_id
    proc_id
    ap_id
    template_id
    fc_id
    q20_count
    q20_bucket
    pass_fail_tag
    capillary
    read_length
    vector_left
    vector_right
);

my @relevant_dimension_tables = qw(
        seq_dim
        source_sample_dim
        run_dim
        processing_dim
        archive_project_dim
);

################################################ M E T H O D S #
#get/set methods
__PACKAGE__->mk_accessors(@columns);
__PACKAGE__->mk_accessors(@relevant_dimension_tables);

#database attributes
sub table_name { return 'read_fact' }
sub columns { return @columns; }
sub primary_key { return "read_id"; }

sub new {
    my $class = shift;
    my $self = {@_};
    bless($self, $class);
    $self->init_cloned_star_dbh;
    return $self;
}

sub derive_read_length {
    my $self = shift;

    my $r = $self->read();

    my $sr = GSC::Sequence::Read->get($r->id);

    if (defined $sr->seq_length) {
        return $sr->seq_length;
    } else {
        return length($sr->sequence_base_string);
    }
}

sub derive_vector_left {
    my $self = shift;

    my $r = $self->read;

    return $r->seq_vec_pos_left || 0;

}

sub derive_vector_right {
    my $self = shift;

    my $r = $self->read;

    my $vr = $r->seq_vec_pos_right;

    if (!defined $vr) {
        return 0;
    }

    return ($self->derive_read_length - $vr);
}

sub derive_q20_count {
    my $self = shift;
    
    my $r = $self->read();
    return $r->q20_count();
}

sub derive_pass_fail_tag {
    my $self = shift;
    my $r = $self->read();
    return $r->pass_fail_tag();
}

sub derive_capillary {
    my $self = shift;
    my $r = $self->read();
    return $r->capillary();
}


sub derive_fc_id {
    my $self = shift;
    
    my $r = $self->read();
    return $r->funding_id();
}

sub derive_q20_bucket {
    my $self = shift;
    
    my $r = $self->read();
    return $r->qstat_20();
}

sub derive_template_id {
    my $self = shift;
    
    my $r =  $self->read;
    my $sr = GSC::Sequence::Read->get($r->id);
    my $template_name = $sr->template_id;

    return $template_name;
}

sub derive_read_id {
    my $self = shift;
    
    my $r = $self->read();
    return $r->re_id();
}

sub derive_ap_id {
    my $self = shift;
    
    my $archive_project_dim = $self->archive_project_dim();
    return $archive_project_dim->ap_id();
}

sub derive_sd_id {
    my $self = shift;
    
    my $seq_dim = $self->seq_dim();
    return $seq_dim->sd_id();
}

sub derive_ss_id {
    my $self = shift;
    
    my $source_sample_dim = $self->source_sample_dim();
    return $source_sample_dim->ss_id();
}

sub derive_run_id {
    my $self = shift;
    
    my $run_dim = $self->run_dim();
    return $run_dim->run_id();
}

sub derive_proc_id {
    my $self = shift;
    
    my $project_dim = $self->processing_dim();
    return $project_dim->proc_id();
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

# P A C K A G E  L O A D I N G ######################################
1;

#$Header$
