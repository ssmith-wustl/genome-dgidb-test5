package Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Bwa;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use Genome::Model::Command::Build::ReferenceAlignment::AlignReads;

class Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Bwa {
    is => [
        'Genome::Model::Command::Build::ReferenceAlignment::AlignReads',
    ],
	has => [
            _calculate_total_read_count => { via => 'instrument_data'},
        #make accessors for common metrics
        (
            map {
                $_ => { via => 'metrics', to => 'value', where => [name => $_], is_mutable => 1 },
            }
            qw/total_read_count/
        ),
    ],
};

sub help_brief {
    "Use bwa to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads bwa --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=4500]' -M 4500000 -n 4";
}


sub metrics_for_class {
    my $class = shift;

    my @metric_names = qw(
                          total_read_count
                          total_reads_passed_quality_filter_count
                          total_bases_passed_quality_filter_count
                          poorly_aligned_read_count
                          aligned_read_count
                          aligned_base_pair_count
                          unaligned_read_count
                          unaligned_base_pair_count
                          total_base_pair_count
    );

    return @metric_names;
}

sub total_reads_passed_quality_filter_count {
    my $self = shift;
    return $self->get_metric_value('total_reads_passed_quality_filter_count');
}

sub _calculate_total_reads_passed_quality_filter_count {
    my $self = shift;
    my $total_reads_passed_quality_filter_count;
    do {
        no warnings;

        unless ($total_reads_passed_quality_filter_count) {
            my @f = grep {-f $_ } $self->instrument_data->fastq_filenames;
            unless (@f) {
                $self->error_message("Problem calculating metric...this doesn't mean the step failed");
                return 0;
            }
            my ($wc) = grep { /total/ } `wc -l @f`;
            $wc =~ s/total//;
            $wc =~ s/\s//g;
            if ($wc % 4) {
                warn "run $a->{id} has a line count of $wc, which is not divisible by four!"
            }
            $total_reads_passed_quality_filter_count = $wc/4;
        }
    };
    return $total_reads_passed_quality_filter_count;
}

sub total_bases_passed_quality_filter_count {
    my $self = shift;
    return $self->get_metric_value('total_bases_passed_quality_filter_count');
}

sub _calculate_total_bases_passed_quality_filter_count {
    my $self = shift;

    # total_reads_passed_quality_filter_count might return "Not Found"
    no warnings 'numeric';
    my $total_bases_passed_quality_filter_count = $self->total_reads_passed_quality_filter_count * $self->instrument_data_assignment->read_length;
    return $total_bases_passed_quality_filter_count;
}

sub poorly_aligned_read_count {
    my $self = shift;
    
    return $self->get_metric_value('poorly_aligned_read_count');
}

sub _calculate_poorly_aligned_read_count {
    my $self = shift;

    #unless ($self->should_calculate) {
    #    return 0;
    #}
    my $instrument_data_assignment = $self->instrument_data_assignment;
    my $alignment = $instrument_data_assignment->alignment;
    my $total = 0;
    for my $f ($alignment->unaligned_reads_list_paths) {
        my $fh = IO::File->new($f);
        $fh or die "Failed to open $f to read.  Error returning value for poorly_aligned_read_count.\n";
        while (my $row = $fh->getline) {
            $total++
        }
    }
    return $total;
}

sub aligned_read_count {
    my $self = shift;
    return $self->get_metric_value('aligned_read_count');
}

sub _calculate_aligned_read_count {
    my $self = shift;
    no warnings 'numeric';
    # total_reads_passed_quality_filter_count might return "Not Found"
    my $aligned_read_count = $self->total_reads_passed_quality_filter_count - $self->poorly_aligned_read_count;
    return $aligned_read_count;
}

sub aligned_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('aligned_base_pair_count');
}

sub _calculate_aligned_base_pair_count {
    my $self = shift;

    my $aligned_base_pair_count = $self->aligned_read_count * $self->instrument_data_assignment->read_length;
    return $aligned_base_pair_count;
}
sub unaligned_read_count {
    my $self = shift;
    return $self->get_metric_value('unaligned_read_count');
}

sub _calculate_unaligned_read_count {
    my $self = shift;
    my $unaligned_read_count = $self->poorly_aligned_read_count;
    return $unaligned_read_count;
}

sub unaligned_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('unaligned_base_pair_count');
}

sub _calculate_unaligned_base_pair_count {
    my $self = shift;
    my $unaligned_base_pair_count = $self->unaligned_read_count * $self->instrument_data_assignment->read_length;
    return $unaligned_base_pair_count;
}

sub total_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('total_base_pair_count');
}

sub _calculate_total_base_pair_count {
    my $self = shift;

    my $total_base_pair_count = $self->total_read_count * $self->instrument_data_assignment->read_length;
    return $total_base_pair_count;
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    
    print Data::Dumper::Dumper($self);
    $DB::single = 1;
    
    #old AssignRun step 
    unless (-d $self->build_directory) {
        $self->create_directory($self->build_directory);
        $self->status_message("Created build directory: ".$self->build_directory);
    } else {
        $self->status_message("Build directory exists: ".$self->build_directory);
    }
    
    # undo any changes from a prior run
    $self->revert;

    my $instrument_data_assignment = $self->instrument_data_assignment;
    my @alignments = $instrument_data_assignment->alignments;
    my @errors;
    for my $alignment (@alignments) {
        # ensure the alignments are present
        unless ($alignment->find_or_generate_alignment_data) {
            $self->error_message("Error finding or generating alignments!:\n" .  join("\n",$alignment->error_message));
            push @errors, $self->error_message;
        }
    }
    if (@errors) {
        $self->error_message(join("\n",@errors));
        return 0;
    }

    $self->generate_metric($self->metrics_for_class);

    unless ($self->verify_successful_completion) {
        $self->error_message("Error verifying completion!");
        return 0;
    }

    return 1;
}



sub verify_successful_completion {
    my $self = shift;

    unless (-d $self->build_directory) {
    	$self->error_message("Build directory does not exist: " . $self->build_directory);
        return 0;
    }

    my $instrument_data_assignment = $self->instrument_data_assignment;
    my @alignments = $instrument_data_assignment->alignments;
    my @errors;
    for my $alignment (@alignments) {
        unless ($alignment->verify_alignment_data) {
            $self->error_message('Failed to verify alignment data: '.  join("\n",$alignment->error_message));
            push @errors, $self->error_message;
        }
    }
    if (@errors) {
        $self->error_message(join("\n",@errors));
        return 0;
    }

    return 1;
}


1;

