package Finishing::Project::AcefileSplitter;

use strict;
use warnings;

use base 'Finishing::Project::Splitter';

use Data::Dumper;
use GSC::IO::Assembly::Ace;
#use Finishing::Assembly::AceSQLite;

my %acefile :name(acefile:r)
    :type(input_file)
    :clo('af=s')
    :desc('Acefile to split');
my %ace_dbfile :name(ace_dbfile:o)
    :type(input_file)
    :clo('ace-db=s')
    :desc("Ace db file");
my %ace :name(_ace:p) :type(inherits_from) :options([qw/ GSC::IO::Assembly::Ace /]);
my %ctg_namer :name(_ctg_namer:p) :type(defined);
my %ctg_names :name(_ctg_names:p) :type(aryref);

sub START
{
    my $self = shift;

    my %ace_p = ( input_file => $self->acefile );
    if ( $self->ace_dbfile )
    {
        $ace_p{conserve_memory} = 1;
        $ace_p{dbfile} = $self->ace_dbfile;
    }
    elsif ( -s $self->acefile . '.db' )
    {
        $self->ace_dbfile( $self->acefile . '.db' );
        $ace_p{conserve_memory} = 1;
        $ace_p{dbfile} = $self->ace_dbfile;
    }

    my $ace = GSC::IO::Assembly::Ace->new(%ace_p);
    $self->error_msg(sprintf('Can\'t open acefile (%s)', $self->acefile))
        and return unless $ace;

    $self->_ace($ace)
        or return;

    $self->_ctg_names( $ace->get_contig_names )
        or return;

    unless ( $self->_queue_contig )
    {
        $self->error_msg(sprintf('Error queueing ctg for acefile (%s)', $self->acefile));
        return;
    }

    return 1;
}

sub _queue_contig : PRIVATE
{
    my $self = shift;

    my @ctg_names = @{ $self->_ctg_names };
    if ( @ctg_names )
    {
        $self->{_queued_contig} = $self->_ace->get_contig( shift @ctg_names );
        $self->_ctg_names(\@ctg_names);
    }
    else
    {
        $self->{_queued_contig} = undef;
    }

    return 1;
}

sub _get_contigs_name : PRIVATE
{
    my ($self, $contig) = @_;

    $self->error_msg("Need contig to get name")
        and return unless $contig;
    
    return $contig->name;
}

sub _get_contigs_unpadded_end : PRIVATE
{
    my ($self, $contig) = @_;

    $self->error_msg("Need contig to get upadded end")
        and return unless $contig;

    return $contig->base_count;
}

1;

