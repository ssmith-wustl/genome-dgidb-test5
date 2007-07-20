# Rename the final word in the full class name <---
package Genome::Model::Command::Alnview;

use strict;
use warnings;

use UR;
use Command;

use Fcntl;
use Carp;



UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => ['pos','file'],                   # Specify the command's properties (parameters) <--- 
);

sub help_brief {
    "Display information inside the packed alignment file"                     # Keep this to just a few words <---
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<"EOS"

--file <path_to_alignment_file>  The prefix of the alignment index and data files, without the '_aln.dat'
--pos <integer>    The alignment position to display information for

If --pos is ommitted, it displays the max alignment position in the index
EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute <---
#    my $class = shift;
#    my %params = @_;
#
#    my $self = $class->SUPER::create(%params);
#
#    return $self;
#}

#sub validate_params {                      # Pre-execute checking.  Not requiried <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}


sub execute {
    my $self = shift;
$DB::single=1;

    require Genome::Model::RefSeqAlignmentCollection;

    my $file = $self->file;
    my $alignment = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $file);
    unless ($alignment) {
        print "Can't access alignment data\n";
        return;
    }

    unless ($self->pos) {
        print "Max alignment position is ",$alignment->max_alignment_pos,"\n";
        return 1;
    }

    my $is_sorted = 1;
    my $last_alignment_num = $alignment->_read_index_record_at_position($self->pos);
    my $count = 0;
    while($last_alignment_num) {
        $count++;
        my $record = $alignment->get_alignment_node_for_alignment_num($last_alignment_num);
        my $aln_obj = Genome::Model::Alignment->new($record);

        print "At alignment number $last_alignment_num:\n";
        $self->print_alignment_object($aln_obj);
        
        if ($record->{'last_alignment_number'} != 0 &&
            $record->{'last_alignment_number'} != $last_alignment_num - 1) {

            $is_sorted = 0;
        }

        $last_alignment_num = $record->{'last_alignment_number'};
    }

    print "There were $count alignment records at position ",$self->pos,"\n";
    print "This alignment file is probably ",
          $is_sorted ? '' : ' NOT ',
          "sorted\n" if ($count > 1);

    return 1;
}


sub print_alignment_object {
my($self,$aln_obj) = @_;

    foreach my $method (qw( read_number probability some_length orientation number_of_alignments
                            mismatch_string reference_bases query_base_probability_vectors last_alignment_number)) {
        my $val = $aln_obj->$method;
        $val = '' unless defined $val;
        printf("%20s => %s\n", $method, $val);
    }
    print "\n";
}



1;

