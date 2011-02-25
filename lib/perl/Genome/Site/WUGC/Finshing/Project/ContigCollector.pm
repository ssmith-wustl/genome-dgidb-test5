package Finishing::Project::ContigCollector;

use strict;
use warnings;

use base qw(Finfo::Singleton);

use Data::Dumper;
use File::Basename;
use GSC::IO::Assembly::Ace;
use Finishing::Project::Utils;

my %project :name(project:r) :type(non_empty_hashref);
my %ace :name(ace:r) :type(inherits_from) :options([qw/ Finishing::Assembly::Ace /]);

sub START
{
    my $self = shift;

    return Finishing::Project::Utils->instance->validate_project( $self->project );
}

sub execute
{
    my $self = shift;

    my $project = $self->project;
    my $ace = $self->ace;

    $self->info_msg("Collecting contigs for $project->{name}");
    
    foreach my $name ( sort { $self->_sort_contigs } keys %{ $project->{contigs} } )
    {
        my $ctg = $project->{contigs}->{$name};
        if ( exists $ctg->{aceinfo} )
        {
            my $ace_ctg = $self->_grab_contig_from_acefile($name, $ctg)
                or return;
            $ace->add_contig($ace_ctg);# can we check for this??
        }
        elsif ( exists $ctg->{seqinfo} )
        {
            my $seq_ctg = $self->_grab_contig_from_db($name, $ctg)
                or return;
            #TODO convert seq ctg to ace ctg
            my $ace_ctg = GSC::IO::Assembly::Contig->new
            (
                name => $ctg->sequence_item_name
                #etc...
            );
            $self->error_msg("Could not create GSC::IO::Assembly::Contig from GSC::Sequence::Contig")
                and return unless $ace_ctg;
            $ace->add_contig($ace_ctg);# can we check for this??
        }
        else
        {
            $self->error_msg("No source to get contig from for project ($project->{name})");
            return;
        }
    }

    return 1;
}

sub _sort_contigs : PRIVATE
{
    $a =~ /Contig(\d+)(?:\.(\d+))*/;
    my $a_super = $1;
    my $a_reg = (defined $2)
    ? $2
    : 0;
    
    $b =~ /Contig(\d+)(?:\.(\d+))*/;
    my $b_super = $1;
    my $b_reg = (defined $2)
    ? $2
    : 0;

    return $a_reg <=> $b_reg if $a_reg and $b_reg;
    
    return $a_super <=> $b_super;
}

sub _grab_contig_from_acefile : PRIVATE
{
    my ($self, $new_name, $ctg) = @_;
    
    my ($acefile, $name) = split(/=/, $ctg->{aceinfo});

    return unless Finfo::Validate->validate
    (
        attr => 'ctg name to get',
        value => $name,
        type => 'defined',
        err_cb => $self,
    );

    return unless Finfo::Validate->validate
    (
        attr => 'acefile',
        value => $acefile,
        type => 'input_file',
        err_cb => $self,
    );

    my $tmp_ace;
    if ( $acefile =~ /\.gz$/ )
    {
        # TODO manage better...
        my $ace_base = basename($acefile);
        $tmp_ace = "/tmp/$ace_base";
        unlink $tmp_ace if -e $tmp_ace;
        system "gunzip -c $acefile > $tmp_ace";
        $acefile = $tmp_ace;
        push @{ $self->{_tmp_acefiles} }, $acefile;
    }

    my %ace_p = 
    (
        input_file => $acefile,
        conserve_memory => 1,
    );

    my $ace_dbfile = $acefile . '.db';
    if ( -s $ace_dbfile ) # pass it in, but don't queue to delete
    {
        $ace_p{dbfile} = $ace_dbfile;
    }
    else # queue to delete on destroy
    {
        push @{ $self->{ace_dbfiles} }, $ace_dbfile;
    }

    my $aceobject = GSC::IO::Assembly::Ace->new(%ace_p);
    $self->error_msg("Failed to create GSC::IO::Assembly::Ace for acefile ($acefile)")
        and return unless $aceobject; 

    my $contig = $aceobject->get_contig($name);
    $self->error_msg("Can't get contig ($name) from acefile ($acefile)")
        and return unless $contig;

    my $new_contig;
    if (0)# TODO( exists $ctg->{start} or exists $ctg->{stop} ) 
    {
        my $am = Finishing::ProjectWorkBench::Model::Ace->new(aceobject => $aceobject);

        my $start = $contig->{start} || 1;
        my $stop = $contig->{stop} || $contig->length; # TODO

        my %reads = 
        (
            map { $_->name => $_ }
            @{ $am->contigs_to_reads(contig_string => sprintf('%s=%dto%d', $name, $start, $stop)) },
        );

        $new_contig = GSC::IO::Assembly::Contig->new(reads => \%reads)
            or die;

        $new_contig->name($new_name);
        $new_contig->calculate_consensus($start, $stop);
        $self->info_msg("Done $new_name");
        $new_contig->calculate_base_segments($start, $stop);
        #$new_contig->tags( $am->contigs_to_base_segments() );
    }
    else
    {
        $new_contig = $contig;
        $new_contig->name($new_name);
        $new_contig->tags([ grep { $_->parent($new_name) } @{ $new_contig->tags } ]);
    }

    # TODO
    if (0)# exists $ctg->{tags} )
    {
        my @tags;
        foreach my $tag_ref ( @{ $ctg->{tags} } )
        {
            push @tags, GSC::IO::Assembly::Tag->new
            (
                parent => $new_name,
                start => $tag_ref->{start} || 1,
                stop => $tag_ref->{stop} || $contig->length,
                type => $tag_ref->{type} || 'comment',
                source => $tag_ref->{source} || 'Project::Maker',
                no_trans => $tag_ref->{no_trans},
            )
                or die;
        }

        $new_contig->tags(\@tags);
    }

    return $new_contig;
}

sub _grab_contig_from_db : PRIVATE
{
    my ($self, $new_name, $ctg) = @_;

    my $contig = Finishing::Project::Utils->instance->get_gsc_seq_item($ctg->{seqinfo})
        or return;

    return unless Finishing::Project::Utils->instance->validate_new_seq_name($new_name);

    my $new_contig;
    if ( exists $ctg->{start} or exists $ctg->{stop} ) 
    {
        $new_contig = $contig->create_subcontig
        (
            $new_name,
            $ctg->{start} || 1,
            $ctg->{stop} || $contig->length, # TODO
        );
    }
    else
    {
        $new_contig = $contig->copy_contig($new_name);
    }

    # TODO
    if (0)# exists $ctg->{tags} )
    {
        my @tags;
        foreach my $tag_ref ( @{ $ctg->{tags} } )
        {
            push @tags, GSC::Sequence::Tag->new
            (
                parent => $new_name,
                start => $tag_ref->{start} || 1,
                stop => $tag_ref->{stop} || $contig->length,
                type => $tag_ref->{type} || 'comment',
                source => $tag_ref->{source} || 'Project::Maker',
                no_trans => $tag_ref->{no_trans},
            )
                or die;
        }

        $new_contig->tags(\@tags);
    }

    return $new_contig;
}

# Clean up ace tmp files
sub DESTROY
{
    my $self = shift;

    return 1 unless $self->{_tmp_acefiles};
    
    foreach my $tmp_af ( @{ $self->{_tmp_acefiles} } )
    {
        $self->info_msg("Removing $tmp_af"); next;
        unlink $tmp_af if -e $tmp_af;
    }

    foreach my $dbfile ( @{ $self->{_ace dbfiles} } )
    {
        $self->info_msg("Removing $dbfile"); next;
        unlink $dbfile if -e $dbfile;
    }

    return 1;
}
