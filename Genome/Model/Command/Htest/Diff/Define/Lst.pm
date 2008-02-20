package Genome::Model::Command::Htest::Diff::Define::Lst;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

use IO::File;

class Genome::Model::Command::Htest::Diff::Define::Lst {
    is => 'Genome::Model::Command::Htest::Diff::Define',
};

sub help_brief {
    "Load a reference diff in .lst format into the database and create a new, patched reference from it ";
}

sub help_synopsis {
    return <<"EOS"
    genome-model htest diff define --from-path /my/old/consensus --changes /my/file --to-path /my/new/consensus
EOS
}

sub help_detail {                           
    return <<EOS 
Load a reference diff into the database.  See the sub-commands for what formats are acceptable.
EOS
}


sub load_changes_file {
    my $self = shift;

    my $fh = IO::File->new($self->changes);
    unless ($fh) {
        $self->error_message("Can't open changes file ".$self->changes.": $!");
        return;
    }

    my $diff_obj = Genome::Model::SequenceDiff->create(from_path => $self->from_path, to_path => $self->to_path, description => 'imported from .lst format');
    
    my $patched_offset;  # How different the patched ref position is from the original
    while (<$fh>) {
        chomp;
        my($refseq_path, $position, $original_seq, $replacement_seq, $code) = split;
        unless ($refseq_path && $position && $original_seq && $replacement_seq && $code) {
            $self->error_message("Couldn't parse line ",$fh->input_line_number," of .lst file ",$self->changes);
            return;
        }

        chop $refseq_path if ($refseq_path =~ m/,$/);  # Get rid of the trailing comma

        # FIXME what do we do with indels with length greater than 1?
        my $diff_part = Genome::Model::SequenceDiffPart->create(diff_id => $diff_obj->diff_id,
                                                                refseq_path => $refseq_path,
                                                                orig_position => $position,
                                                                orig_length => length($original_seq),
                                                                orig_sequence => $original_seq,  
                                                                patched_position => $position + $patched_offset,
                                                                patched_length => length($replacement_seq),
                                                                patched_sequence => $replacement_seq,
                                                                confidence_value => 1,  # Maybe $code has something to do with it?
                                                              );
	$patched_offset += $diff_part->orig_length - $diff_part->patched_length;
    }
                                                                
    return $diff_obj;
}


1;

