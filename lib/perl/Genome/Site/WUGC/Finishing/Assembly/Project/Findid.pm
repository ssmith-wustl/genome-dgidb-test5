package Finishing::Assembly::Project::Findid;

use strict;
use warnings;

use Finfo::Std;

my %project_name :name(project_name:r);
my %species :name(species:r);
my %reader :name(reader:p) :isa('object');

my %alignments :name(_alignmnents:p)
    :ds(aryref);

sub age
{
    return sprintf("%d", -M shift->file);
}

sub alignments
{
    my $self = shift;

    return @{ $self->_alignments } if $self->_alignments;

    my $fh = IO::File->new("< " . $self->file);
    $self->error_msg("Can't open " . $self->file)
        and return unless $fh;
    
    my $fr = GSC::IO::Alignment::Findid::Reader->new($fh);
    my @alignments = $fr->all_alignments;
    $fh->close;
    
    $self->error_msg("No alignments found in " . $self->file)
        and return unless @alignments;
    
    return @{ $self->_alignments( \@alignments ) };
}

sub identities_for_hit
{
    my ($self, $query_contig_name, $subject_name, $subject_sub_name) = @_;
    
    foreach my $alignment ( $self->alignments )
    {
        next unless $query_contig_name eq $alignment->query_contig_name
            and $subject_name eq $alignment->subject_name
            and ($subject_sub_name eq $alignment->subject_contig_name 
                or $subject_sub_name eq $alignment->subject_id);

        my @ids = $alignment->identities;

        $self->info_msg
        (
            "No identities exist for the alignemnet object matching subject",
            "contig name: $subject_sub_name and query contig name: $query_contig_name."
        ) and return unless @ids;

        return @ids;
    }

    $self->info_msg
    (
        "An alignment object matching query contig name: $query_contig_name ", 
        "and subject contig name: $subject_sub_name was not found."
    );

    return;
}

sub check_screen
{
    my ($self, $db) = @_;

    return scalar grep $_->blastdb =~ /$db/i, $self->alignments;
}

sub self_hits
{
    my $self = shift;

    my @self_hits;
    foreach my $alignment ( $self->alignments )
    {
        next unless $alignment->subject_name eq $alignment->query_name;
        push @self_hits, $alignment if $alignment->identities;
    }
    
    return @self_hits;
}

sub largest_self_hit
{
    my $self = shift;
    
    my $largest_self_hit;
    foreach my $alignment ( $self->alignments)
    {
        next unless $alignment->subject_name eq $alignment->query_name;

        next unless $alignment->identities;

        $largest_self_hit = $alignment unless defined $largest_self_hit;

        $largest_self_hit = $alignment if $alignment->query_size >= $largest_self_hit->query_size;
    }
    
    return unless $largest_self_hit;
    
    return ($largest_self_hit->query_contig_name, $largest_self_hit->query_size);
}

sub subject_hits
{
    my ($self, $subject, $length, $per_match) = @_;

    my @subject_hits;
    foreach my $alignment ( $self->alignments )
    {
        next unless $alignment->subject_name =~ /$subject/i;

        my @ids = $alignment->identities;
        
        next unless @ids; # No matches

        if (defined $per_match)
        {
            push @subject_hits, $alignment
            if grep $_->percent_match >= $per_match, @ids
                and grep $_->total_residues >= $length, @ids;
        }
        else
        {
            push @subject_hits, $alignment;
        }
    }
    
    return @subject_hits;
}

sub same_species_hits
{
    my ($self, $length, $per_match) = @_;

    return $self->species_hits($self->species, $length, $per_match);
}

sub species_hits
{
    my ($self, $species, $length, $per_match) = @_;

    print $species,"\n";
    
    $self->error_msg("No species defined")
        and return unless defined $species;

    $length = 0 unless defined $length;
    $per_match = 0 unless defined $per_match;

    my @species_hits;
    foreach my $alignment ( $self->alignments )
    {
        my $db = $alignment->blastdb;
        next unless $species =~ /$db/i;
        next if $alignment->subject_name eq $alignment->query_name; # self hit

        my @ids = $alignment->identities;
        
        next unless @ids; # No matches

        push @species_hits, $alignment if grep $_->total_residues >= $length, @ids
            and grep $_->percent_match >= $per_match, @ids;
    }

    return @species_hits;
}

sub transposon_hits
{
    my $self = shift;

    my @transpson_identifiers = $self->transposon_identifiers;
    my @trans_hits;
    foreach my $alignment ( $self->alignments )
    {
        next unless grep $alignment->subject_name =~ /$_/, @transpson_identifiers;

        push @trans_hits, $alignment if $alignment->identities;
    }

    return @trans_hits;
}

sub transposon_identifiers
{
    return
    (qw/
        nsertion
        ransposon
        lement
        IS
    /);
}

1;
=pod

=head1 Name

Assembly::Finishing::Project::Findid

=head1 Synopsis

Provides access to a project's findid (blast) output.

=head1 Usage

 use Finishing::Assembly::Factory;
 
 my $factory = Finishing::Assembly::Factory->connect('gsc');
 my $project = $factory->get_project('C_AB0278M16');
 my $findid = $project->findid;

  * or directly *

 use Finishing::Assembly::Project::Findid;
 use Alignment::Findid::Reader;

 my $findid = Finishing::Assembly::Project::Findid->new
 (
    project_name => 'C_AB0278M16',
    species => 'chimp',
    reader => Alignment::Findid::Reader->new(io => 'parsefinid'),
 );

 ...
 
=head1 Methods

=head2 age

 returns the age of the parsefindid file

=head2 alignments

 return all of the alignments from the parsefindid file

=head2 identities_for_hit

 my @ids = $findid->identities_for_hit($query_contig_name,$subject_name, $subject_sub_name);

 returns the ids of a hit that matches the query_contig_name, subject_name and 
  subject_sub_name.  This is useful if you don't have the hit object.

=head2 check_screen

 my $result = $self->check_screen($screened_db);

 returns the number of times the database was screened against
 
=head2 self_hits

 my @hits = $findid->self_hits;
 
 returns all of the alignments that hit the project_name

=head2 largest_self_hit

 my $hit = $findid->largest_self_hit;

 returns the largest alignment that hit the project_name
 
=head2 subject_hits
 
 my @hits = $findid->subject_hits($subject, $length, $per_match);

 returns the hits that match the subject hit, screening against the min length and percent match

=head2 same_species_hits

 my @hits = $findid->same_species_hits(1000 (min size of march), 98 (percent match) );
 
 returns the hits that match the species of the project, screening against the min length and percent match
 
=head2 species_hits

 my @hits = $findid->species_hits('chicken', 1000 (min size of march), 98 (percent match) );
 
 returns the hits that match the species, screening against the min length and percent match
 
=head2 transposon_hits

 returns all of the alignments that match the transoposon identifiers
 
=head2 transposon_identifiers

 an array of typical transposon identifiers

=head1 Disclaimer

 Copyright (C) 2007 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Assembly/Project/Findid.pm $
#$Id: Findid.pm 31534 2008-01-07 22:01:01Z ebelter $
