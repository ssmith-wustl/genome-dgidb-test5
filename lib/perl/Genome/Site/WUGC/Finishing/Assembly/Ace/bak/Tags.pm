package Genome::Site::WUGC::Finishing::Assembly::Ace::TagFactory;
{
    use strict;
    use warnings;

    use base 'Finfo::Singleton';

    use Data::Dumper;

    sub build_tag_from_reader_hashref
    {
        my ($self, $tag) = @_;
        
        my %types_and_classes =
        (
            assembly_tag => 'Genome::Site::WUGC::Finishing::Assembly::Ace::AssemblyTag',
            contig_tag => 'Genome::Site::WUGC::Finishing::Assembly::Ace::ConsensusTag',
            read_tag => 'Genome::Site::WUGC::Finishing::Assembly::Ace::ReadTag',
        );
        
        my %tag_types_and_class_additions = 
        (
            oligo => 'Oligo',
            autoFinishExp => 'AutoFinishExp',
        );
        
        my $class = $types_and_classes{ delete $tag->{object_type} };
        if ( my $addition = $tag_types_and_class_additions{ $tag->{type} } )
        {
            $class .= '::' . $addition;
        }

        return $class->new(%$tag);
    }

    1;
}

##################################################################

package Genome::Site::WUGC::Finishing::Assembly::Ace::Tag;
{

    use strict;
    use warnings;
    
    use Finfo::Std;
    
    my %type :name(type:r) :isa(string);
    my %program :name(program:r) :isa(string);
    my %date :name(date:r) :isa(string);
    my %text :name(text:o) :isa(string);
    my %comment :name(comment:o) :isa(string);

    1;
}

##################################################################

package Genome::Site::WUGC::Finishing::Assembly::Ace::AssemblyTag;
{

    use strict;
    use warnings;
    
    use base 'Genome::Site::WUGC::Finishing::Assembly::Ace::Tag';
    
    1;
}

##################################################################

package Genome::Site::WUGC::Finishing::Assembly::Ace::SequenceTag;
{

    use strict;
    use warnings;
    
    use base 'Genome::Site::WUGC::Finishing::Assembly::Ace::Tag';
    
    my %parent :name(parent:r);
    my %start :name(start:r) :isa('int pos');
    my %stop :name(stop:r) :isa('int pos');
    my %unpad_start :name(unpad_start:o) :isa('int pos');
    my %unpad_stop :name(unpad_stop:o) :isa('int pos');

    1;
}

##################################################################

package Genome::Site::WUGC::Finishing::Assembly::Ace::ConsensusTag;
{
    use base 'Genome::Site::WUGC::Finishing::Assembly::Ace::SequenceTag';

    my %no_trans :name(no_trans:o) :default(0);

    1;
}

##################################################################

package Genome::Site::WUGC::Finishing::Assembly::Ace::AutoFinishExpTag;
{
    use strict;
    use warnings;
              
    use base 'Genome::Site::WUGC::Finishing::Assembly::Ace::ConsensusTag';

    my %ori :name(orientation:o);
    my %n1 :name(num1:o);
    my %n2 :name(num2:o);
    my %n3 :name(num3:o);
    my %chem :name(chem:o);
    my %pt :name(primer_type:o);
    my %purp :name(purpose:o);
    my %fce :name(fix_cons_errors:o);
    my %oce :name(original_cons_errors:o);
    my %ossb :name(original_single_subclone_bases:o);
    my %primer :name(primer:o);
    my %temp :name(temp:o);
    my %id :name(id:o);
    my %ei_and_template :name(exp_id_and_template:o);
    my %o_name :name(oligo_name:o);
    my %o_seq :name(oligo_seq:o);
    my %o_temp :name(oligo_temp:o);

    1;
}

##################################################################

package Genome::Site::WUGC::Finishing::Assembly::Ace::OligoTag;
{

    use strict;
    use warnings;

    use base 'Genome::Site::WUGC::Finishing::Assembly::Ace::ConsensusTag';

    my %name :name(oligo_name:r) :isa(string);
    my %seq :name(oligo_seq:r) :isa(string);
    my %temp :name(oligo_temp:r) :isa('int pos');
    my %templates :name(oligo_templates:r) :ds(aryref);
    my %orientation :name(orientation:r) :isa('in_list U C');

    1;
}

##################################################################

package Genome::Site::WUGC::Finishing::Assembly::Ace::ReadTag;
{

    use base 'Genome::Site::WUGC::Finishing::Assembly::Ace::SequenceTag';

    1;
}

=pod

=head1 Name

 Genome::Site::WUGC::Finishing::Assembly::Tag::Oligo - Represents an oligo tag on a Genome::Site::WUGC::Finishing::Assembly::Item

  > Inherits from Genome::Site::WUGC::Finishing::Assembly::Tag;

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

=head1 Name

 Genome::Site::WUGC::Finishing::Assembly::Tag::Oligo - Represents an oligo tag on a Genome::Site::WUGC::Finishing::Assembly::Item

  > Inherits from Genome::Site::WUGC::Finishing::Assembly::Tag;

=head2 Contig Tag Format

 CT{
 Contig24 oligo consed 606 621 050427:142133
 M_BB0392D19.29 ccctgagcgagcagga 60 U
 L25990P6000A5 L25990P6000D4
 }

=head1 Methods

 Getters Only!! Add to TagParse.pm and Ace.pm to make these Setters to
  produce the correct output in an ace file

=head2 oligo_name

=head2 oligo_num

=head2 oligo_seq

=head2 oligo_temp

=head2 oligo_templates

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

1;

#$HeadURL$
#$Id$
