package TpEntry;

use strict;
use warnings;

use base qw(Finfo::Object);

use Data::Dumper;
use Date::Format;

sub _reqs
{
    return
    {
        project_name => [qw/ defined /],
        species => [qw/ defined /],
        chromosome => [qw//],
        tp_contig_num => [qw/ defined /],
        tp_pos => [qw/ defined /],
    };
}

sub _opts
{
    return 
    {
        user => [qw/ defined /, $ENV{USER} ],
        create_species => [qw/ defined 0 /], 
        create_chromosome => [qw/ defined 0 /],
    };
}

sub _init
{
    my $self = shift;

    if ( $self->create_species )
    {
        return unless $self->_insert_species;
    }
    
    return unless $self->_check_species;
    
    if ( $self->create_chromosome )
    {
        return unless $self->_insert_chromosome;
    }

    return unless $self->_check_chromosome;
    
    return 1;
}

sub create
{
    my $self = shift;

    my $sql = $self->_tp_entry_sql;

    return unless defined $sql;

    return $self->_execute_sql($sql);
}

sub _tp_entry_sql
{
    my $self = shift;

    my $dbh = App::DB->dbh;
    $self->error_msg("Could not get db handle")
        and return unless defined $dbh;

    my $tp_id = $dbh->selectrow_array("select ssmith.tp_seq.nextval from dual");
    $self->error_msg()
        and return unless defined $tp_id;

    my $change_id = $dbh->selectrow_array("select ssmith.data_change_seq.nextval from dual");
    $self->error_msg()
        and return unless defined $change_id;

    my %tp_params = 
    (
        tp_id => $tp_id,
        center => 'WUGSC',
        territory => 'WUGSC',
        local_clone_name => $self->project_name,
        species_name => $self->species,
        chromosome => $self->chromosome, 
        contig => $self->tp_contig_num,
        position=> $self->tp_pos,
        editor_id => $self->user,
        change_id => $change_id,
        sequence_orientation => '+',
        change_type => 'I',
        version_date => time2str('%Y-%m-%d %H:%M:%S', time),
    );

    return sprintf
    (
        'insert into tp_entry (%s) values (%s)',
        join(", ", sort keys %tp_params), 
        join(", ", map { "'$tp_params{$_}'" } sort keys %tp_params)
    );
}

sub _check_species
{
    my $self = shift;

    my $sth = $self->_execute_sql("select * from species where species = '" . $self->species . "'");

    return unless defined $sth;

    return @{ $sth->fetechall_arrayref };
}

sub _insert_species
{
    my $self = shift;

    return 1 if $self->_check_species;
    
    return $self->_execute_sql("insert into species (species_name) values ('" . $self->species . "')");
}

sub _check_chromosome
{
    my $self = shift;

    my $sth = $self->_execute_sql
    (
        sprintf
        (
            "select * from species_chromosome where species_name = '%s' and chromosome = '%s'", 
            $self->species,
            $self->chromosome,
        )
    );

    return unless $sth;

    return @{ $sth->fetchal_arrayref };
}

sub _insert_chromosome
{
    my $self = shift;
    
    return 1 if $self->_check_chromosome;
    
    return $self->_execute_sql
    (
        sprintf
        (
            "insert into species_chromosome (species_name, chromosome) values ('%s', '%s')",
            $self->species,
            $self->chromosome,
        )
    );
}

sub _execute_sql
{
    my ($self, $sql) = @_;

    $self->error_msg("No sql to execute")
        and return unless defined $sql;

    my $dbh = App::DB->dbh;
    $self->error_msg("Could not db handle")
        and return unless defined $dbh;
    
    my $sth = $dbh->prepare($sql);
    $self->error_msg("Could not prepare sql:\n$sql")
        and return unless $sth;

    $sth->execute
        or ( $self->error_msg("Could not execute sql:\n$sql") and return );
    
    return $sth;
}

1;

=pod

=head1 Name

=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 Disclaimer

 Copyright (C) 2007 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/TpEntry.pm $
#$Id: TpEntry.pm 29849 2007-11-07 18:58:55Z ebelter $

