#:boberkfe seems like execute and verify successful completion could be
#:boberkfe pulled up to the superlass

package Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Imported;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Imported {
    is => [
        'Genome::Model::Command::Build::ReferenceAlignment::AlignReads',
    ],
};

sub help_brief {
    "For imported instrument data aligning";
}

sub help_synopsis {
    return <<EOS
    TBA
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=4000]' -M 4000000 -n 4";
}


sub metrics_for_class {
    my $class = shift;
    my @metric_names = qw(total_read_count total_base_count);
    return @metric_names;
}

sub total_read_count {
    return shift->get_metric_value('total_read_count');
}

sub _calculate_total_read_count {
    return shift->instrument_data->read_count;
}

sub total_base_count {
    return shift->get_metric_value('total_base_count');
}

sub _calculate_total_base_count {
    return shift->instrument_data->base_count;
}


sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    
    print Data::Dumper::Dumper($self);
    $DB::single = 1;
    
    #old AssignRun step 
    unless (-d $self->build_directory) {
        $self->create_directory($self->build_directory);
        $self->status_message('Created build directory: '.$self->build_directory);
    } 
    else {
        $self->status_message('Build directory exists: '.$self->build_directory);
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

    my @metric_names = ();

    for my $metric_name ($self->metrics_for_class) {
        my ($property_name) = $metric_name =~ /^total_(\S+)$/;    
        push @metric_names, $metric_name if $self->instrument_data->$property_name;
    }
    
    $self->generate_metric(@metric_names) if @metric_names;

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
        return;
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

