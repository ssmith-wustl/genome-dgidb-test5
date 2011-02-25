package Genome::Site::WUGC::Finishing::Project::SuperContigSplitter;

use strict;
use warnings;

use base 'Genome::Site::WUGC::Finishing::Project::Splitter';

my %superctg :name(supercontig:r) 
    # TODO change to seq_id or name
    :type(inherits_from) 
    :options([ 'GSC::Sequence::SuperContig' ]);
my %ci_done :name(_ci_done:p) :type(defined) :default(0);
my %ctg_iterator :name(_contig_iterator:p) :type(defined);

sub START
{
    my $self = shift;

    my $dbh = GSC::Sequence::Item->dbh;
    $self->error_msg("Can't dbh for seq item table")
        and return unless $dbh;

    my $sth = $dbh->prepare
    (
        sprintf
        (
            'select max(start_position) from sequence_position where parent_seq_id = %d',
            $self->supercontig->seq_id
        )
    );
    $self->error_message( $DBI::errstr )
        and return unless $sth;

    $sth->execute
        or ( $self->error_message( $DBI::errstr ) and return );

    my ($stop_seq_pos) = $sth->fetchrow_array;
    
    my $sc_name = $self->supercontig->sequence_item_name;
    $self->error_msg("Could not get last contig seq pos for $sc_name")
        and return unless defined $stop_seq_pos;
    
    my $ci = GSC::Sequence::ChildIterator->new
    (
        parent_seq_id => $self->supercontig->seq_id,
        start_position => 
        {
            operator => 'between', 
            value => [ 1, $stop_seq_pos ], 
        },
    );

    $self->error_msg("Could create contig iterator for $sc_name")
        and return unless $ci;

    $self->_contig_iterator($ci);
    
    $self->_queue_contig
        or ( $self->error_msg("Error getting first contig for $sc_name") and return );
    
    return 1;
}

sub _queue_contig : PRIVATE
{
    my $self = shift;

    return 1 if $self->_ci_done;

    my $ctg = $self->_contig_iterator->next;

    ( $ctg )
    ? $self->_queued_contig($ctg)
    : $self->_ci_done(1);

    return 1;
}

sub _get_contigs_name : PRIVATE
{
    my ($self, $contig) = @_;

    $self->error_msg("Need contig to get name")
        and return unless $contig;
    
    return $contig->sequence_item_name;
}

sub _get_contigs_unpadded_end : PRIVATE
{
    my ($self, $contig) = @_;

    $self->error_msg("Need contig to get upadded end")
        and return unless $contig;
    
    return $contig->get_unpadded_position( $contig->seq_length );
}

1;

