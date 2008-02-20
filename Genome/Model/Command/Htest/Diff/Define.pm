package Genome::Model::Command::Htest::Diff::Define;

#use strict;
#use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::HTest::Diff::Define {
    is => 'Command',
    has => [
	from_path => { is => 'String', is_optional => 0, doc => 'Path to the original refseq' },
        to_path   => { is => 'String', is_optional => 0, doc => 'Path to where the new, patched reference will be located' },
        changes   => { is => 'String', is_optional => 0, doc => 'Path to the formatted diff file' },
    ],
};

sub help_brief {
    "Load a reference diff into the database";
}

#sub help_synopsis {
#    return <<"EOS"
#    genome-model htest diff define --from-path /my/old/consensus --lst-diff /my/file --to-path /my/new/consensus
#EOS
#}

sub help_detail {                           
    return <<EOS 
Load a reference diff into the database.  See the sub-commands for what formats are acceptable.
EOS
}


sub load_changes_file {
    my $self = shift;
    die "Subclass $self didn't define load_chages_file()";
}


sub execute {
    my $self = shift;

    my $diff_obj = $self->load_changes_file();  # subclasses for each diff type should define this
    return unless $diff_obj;

    my @diffs = Genome::Model::SequenceDiffPart->get(diff_id => $diff_obj->diff_id);
    unless (@diffs) {
        $self->error_message('No diff parts found for diff_id ',$diff_obj->diff_id,'?!');
        return;
    }

    # Group them up by reference file
    my %diffs_by_refseq;
    foreach my $diff_part ( @diffs ) {
        push (@{$diffs_by_refseq{$diff->refseq_path}}, $diff_part);
    }

    foreach my $refseq ( keys %diffs_by_refseq ) {
        my @diff_parts = sort { $a->orig_position <=> $b->orig_position } @{$diffs_by_refseq{$refseq}};
        next unless @diff_parts;

        my $orig_ref_path = sprintf('%s/%s.fna', $diff_obj->from_path, $refseq);
        my $orig_ref = TheFormat->open($orig_ref_path);

        my $patched_ref_path = sprintf('%s/%s.fna.bfa', $diff_obj->fto_path, $refseq);
        my $patched_ref = TheFormat->create($patched_ref_path);
      
        my $orig_pos = 0;   # Current position in the original file
        foreach my $diff_part ( @diff_parts ) {
            if ($curr_pos < $diff_part->orig_position) {
                # There's unpatched sequence between the current position and the next diff
                my $orig_sequence = $orig_ref->get_sequence($curr_pos, $diff->orig_position - $curr_pos);
                $patched_ref->write($orig_sequence);
                $curr_pos = $diff_part->orig_position;
            }
            
            if ($diff_part->orig_length) {  # This is a deletion
                $orig_pos += $diff_part->orig_length;
            }
            if ($diff_part->patched_length) { # This is an insertion
                $patched_ref->write($diff_part->patched_sequence);
            }
        }

        # That's all the diffs, write out the rest of the original sequence
        my $orig_sequence = $orig_ref->get_sequence($curr_pos, 'to_the_end');
        $patched_ref->write($orig_sequence);

    }

    $self->status_message("diff_id is ",$diff_obj->diff_id);

    return 1;
}

1;

