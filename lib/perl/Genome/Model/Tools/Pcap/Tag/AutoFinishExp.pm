package Genome::Model::Tools::Pcap::Tag::AutoFinishExp;

use strict;
use warnings;

use base qw(Genome::Model::Tools::Pcap::Tag);

Genome::Model::Tools::Pcap::Tag::AutoFinishExp->mk_ro_accessors
(qw/
    orientation
    num1 num2 num3 
    chem
    primer_type
    purpose
    fix_cons_errors
    original_cons_errors
    original_single_subclone_bases
    primer
    temp
    id
    exp_id_and_template
    /);

our $VERSION = 0.01;

sub ace
{
    my $self = shift;
    
    return unless defined $self->id;

    my ($ace) = $self->id =~ /^(.+)\.\d+$/;

    return $ace;
}

sub exp_ids_and_templates
{
    my $self = shift;

    return $self->{exp_ids_and_templates} if defined $self->{exp_ids_and_templates};
    
    my %ids_and_templates;
    foreach my $rxn ( split /, /, $self->exp_id_and_template )
    {
        my ($id, $template)  = split / /, $rxn;
        $ids_and_templates{$id} = $template;
    }

    $self->{exp_ids_and_templates} = \%ids_and_templates;
    
    return $self->{exp_ids_and_templates};
}

sub exp_ids
{
    my $self = shift;

    my $ids_and_templates = $self->exp_ids_and_templates;

    return unless defined $ids_and_templates and %$ids_and_templates;
    
    return keys %$ids_and_templates;
}

sub template_for_id
{
    my ($self, $id) = @_;

    die "Need exp id to get template\n" unless defined $id;
    
    my $ids_and_temps = $self->exp_ids_and_templates;

    return unless defined $ids_and_temps and %$ids_and_temps;
    
    return $ids_and_temps->{$id};
}

1;

=pod

=head1 Name

 Genome::Model::Tools::Pcap::Tag::Oligo - Represents an oligo tag on a GSC::IO::Assembly::Item

  > Inherits from Genome::Model::Tools::Pcap::Tag;

=head2 Contig Tag Format

 The format may vary, pending on the parameters used when running auto finish
 
    CT{
   Contig29.2 autoFinishExp autofinish 119 119 060831:122829
   C
   purpose: weak
   0 915 0
   dyeTerm customPrimer
   fix cons errors: 4.69881 original cons errors: 5.64249
   original single subclone bases: 886
   primer: ggcaaatatggtgcaataaaac temp: 58 id: Trichinella_spiralis_060315.pcap.scaffold29.ace.AE.1.1
   expID_and_template: 1 TPAA-ail08c06
   }

=head1 Methods

 Getters Only!! Add to TagParse.pm and Ace.pm to make these Setters to
  produce the correct output in an ace file

=head2 orientation

=head2 num1 num2 num3 

 not sure what these are...

=head2 chem

=head2 primer_type

=head2 purpose

=head2 fix_cons_errors

=head2 original_cons_errors

=head2 original_single_subclone_bases

=head2 primer

=head2 temp

=head2 id

=head2 expid_and_template

=head2 expids_and_templates

 hash ref of exp ids and templats

=head2 exp_ids

 array of exp ids from string expid_and_template
 
=head2 ace

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Lynn Carmicheal <lcarmich@watson.wustl.edu>
 Jon Schindler <jschindl@watson.wustl.edu>
 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
