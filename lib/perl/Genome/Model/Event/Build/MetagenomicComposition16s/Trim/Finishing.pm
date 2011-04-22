package Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Finishing;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
use Genome::Model::Tools::Fasta::ScreenVector; # not sure why gotta use, buttest fails
use Genome::Model::Tools::Fasta::Trim::Trim3; # not sure why gotta use, buttest fails

class Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Finishing {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::Trim',
};

sub execute {
    my $self = shift;

    my @amplicon_set_names = $self->build->amplicon_set_names;
    Carp::confess('No amplicon set names for '.$self->build->description) if not @amplicon_set_names; # bad

    my %trimmer_params = $self->processing_profile->trimmer_params_as_hash; # TODO separate out params - screen only has project name
    for my $name ( @amplicon_set_names ) {
        my $amplicon_set = $self->build->amplicon_set_for_name($name);
        next if not $amplicon_set; # ok

        while ( my $amplicon = $amplicon_set->next_amplicon ) {
            my $fasta_file = $self->build->reads_fasta_file_for_amplicon($amplicon);
            next unless -s $fasta_file; # ok

            my $trim3 = Genome::Model::Tools::Fasta::Trim::Trim3->create(
                fasta_file => $fasta_file,
                %trimmer_params,
            );
            unless ( $trim3 ) { # not ok
                $self->error_message("Can't create trim3 command for amplicon: ".$amplicon->name);
                return;
            }
            $trim3->execute; # ok

            next unless -s $fasta_file; # ok

            my $screen = Genome::Model::Tools::Fasta::ScreenVector->create(
                fasta_file => $fasta_file,
            );
            unless ( $screen ) { # not ok
                $self->error_message("Can't create screen vector command for amplicon: ".$amplicon->name);
                return;
            }
            $screen->execute; # ok

            next unless -s $fasta_file; # ok

            my $qual_file = $self->build->reads_qual_file_for_amplicon($amplicon);
            $self->_add_amplicon_reads_fasta_and_qual_to_build_processed_fasta_and_qual(
                $fasta_file, $qual_file
            )
                or return;
        }
    }

    return 1;
}

1;

