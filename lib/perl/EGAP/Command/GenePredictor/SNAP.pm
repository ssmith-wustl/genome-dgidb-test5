package EGAP::Command::GenePredictor::SNAP;

use strict;
use warnings;

use EGAP;

use Bio::SeqIO;
use Bio::Tools::Prediction::Exon;
use Bio::Tools::Prediction::Gene;

use English;
use IO::Dir;
use IPC::Run;
use File::Temp;
use Carp;
use File::Path qw(make_path);

class EGAP::Command::GenePredictor::SNAP {
    is  => 'EGAP::Command::GenePredictor',
    has => [
        model_file => {
            is => 'Path',
            is_input => 1,
            doc => 'SNAP model file'
        },
    ],
    has_optional => [
        version => {
            is => 'String',
            is_input => 1,
            valid_values => ['2004-06-17', '2007-12-18', '2010-07-28'],
            default => '2010-07-28',
        },        
    ],
};

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    my $self = shift;

    # Use full path to snap executable, with version, instead of the symlink.
    # This prevents the symlink being changed silently and affecting our output!
    my $snap_path = "/gsc/pkg/bio/snap/snap-" . $self->version . "/snap";
    my @cmd = (
        $snap_path,
        '-quiet',
        $self->model_file,
        $self->fasta_file,
    );

    unless (-d $self->output_directory) {
        my $mkdir_rv = make_path($self->output_directory);
        confess "Could not make directory " . $self->output_directory unless $mkdir_rv;
    }

    # TODO This is not sufficient to ensure that there won't be file name conflicts!
    my $output_file = $self->output_directory . "/snap_$$.out";
    unlink $output_file if -e $output_file;

    my $error_file = $self->output_directory . "/snap_$$.err";
    unlink $error_file if -e $error_file;

    eval {    
        IPC::Run::run(
            \@cmd,
            \undef,
            '>',
            $output_file,
            '2>',
            $error_file, 
        ) || die $CHILD_ERROR;
    };

    if ($EVAL_ERROR) {
        confess "Failed to execute snap: $EVAL_ERROR";
    }

    my $snap_fh = IO::File->new($output_file, "r");
    unless ($snap_fh) {
        confess "Could not open " . $output_file . ": $OS_ERROR";
    }

    my %exons;
    my $current_seq_id;

    while (my $line = <$snap_fh>) {
        chomp $line;

        if ($line =~ /^>(.+)$/) {
            $current_seq_id = $1;
        }
        else {
            my (
                $label,
                $begin,
                $end,
                $strand,
                $score,
                $five_prime_overhang,
                $three_prime_overhang,
                $frame,
                $group
            ) = split /\t/, $line;

            my $feature = Bio::SeqFeature::Generic->new(
                -seq_id     => $current_seq_id,
                -start      => $begin,
                -end        => $end,
                -primary    => $label,
                -source_tag => 'SNAP',
                -score      => $score,
                -strand     => $strand,
                -tag        => {
                    'five_prime_overhang'  => $five_prime_overhang,
                    'three_prime_overhang' => $three_prime_overhang },
            );

            push @{$exons{$group}}, $feature;
        }
    }

    my @features;
    foreach my $prediction (keys %exons) {
        my ($strand, $start, $end);	
        my @exons =  sort { $a->start <=> $b->start } @{$exons{$prediction}};
        $start = $exons[0]->start();
        $end   = $exons[$#exons]->end();
        $strand = $exons[0]->strand();

        my $gene = Bio::Tools::Prediction::Gene->new(
            -seq_id       => $exons[0]->seq_id,
            -start        => $start,
            -end          => $end,
            -strand       => $strand,
            -source_tag   => $exons[0]->source_tag(),
            -tag          => {'Sequence' => $prediction},
        );

        if (@exons > 1) {    
            unless ($exons[0]->primary_tag() eq 'Einit' or $exons[$#exons]->primary_tag() eq 'Einit') {
                $gene->add_tag_value('start_not_found' => 1);
                $gene->add_tag_value('fragment' => 1);
            }

            unless ($exons[0]->primary_tag() eq 'Eterm' or $exons[$#exons]->primary_tag() eq 'Eterm') {
                $gene->add_tag_value('end_not_found' => 1);
                $gene->add_tag_value('fragment' => 1);
            }
        }
        elsif (@exons == 1) {
            if ($exons[0]->primary_tag() ne 'Esngl') {
                $gene->add_tag_value('fragment' => 1);

                if ($exons[0]->primary_tag() ne 'Einit') {
                    $gene->add_tag_value('start_not_found' => 1);
                }
                if ($exons[0]->primary_tag() ne 'Eterm') {      
                    $gene->add_tag_value('end_not_found' => 1);
                }
            }
        }

        foreach my $e (@exons) {
            my $exon = Bio::Tools::Prediction::Exon->new(
                -seq_id       => $e->seq_id(),
                -start        => $e->start(),
                -end          => $e->end(),
                -strand       => $e->strand(),
                -score        => $e->score(),
                -source_tag   => $e->source_tag(),
            );
            $exon->add_tag_value('five_prime_overhang' => $e->get_tag_values('five_prime_overhang'));
            $exon->add_tag_value('three_prime_overhang' => $e->get_tag_values('three_prime_overhang'));

            $gene->add_exon($exon);
            $exon->add_tag_value('Sequence' => $gene->get_tag_values('Sequence'));
            $exon->primary_tag('Exon');
        }

        push @features, $gene;
    }

    $self->bio_seq_feature(\@features);
    return 1;
}

1;
