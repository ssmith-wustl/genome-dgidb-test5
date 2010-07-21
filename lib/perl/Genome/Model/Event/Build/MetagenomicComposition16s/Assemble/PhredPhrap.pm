package Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::PhredPhrap;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::PhredPhrap {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::Assemble',
};

sub execute {
    my $self = shift;

    my @amplicon_sets = $self->build->amplicon_sets
        or return;

    my %assembler_params = $self->processing_profile->assembler_params_as_hash;
    for my $amplicon_set ( @amplicon_sets ) {

        my $writer = $self->build->fasta_and_qual_writer_for_type_and_set_name('processed', $amplicon_set->name)
            or return;
    
        while ( my $amplicon = $amplicon_set->next_amplicon ) {
            my $fasta_file = $self->build->reads_fasta_file_for_amplicon($amplicon);
            next unless -s $fasta_file; # ok

            my $phrap = Genome::Model::Tools::PhredPhrap::Fasta->create(
                fasta_file => $fasta_file,
                %assembler_params,
            );

            unless ( $phrap ) { # bad
                $self->error_message(
                    "Can't create phred phrap command for build's (".$self->build->id.") amplicon (".$amplicon->name.")"
                );
                return;
            }

            $phrap->execute;

            $self->build->load_bioseq_for_amplicon($amplicon)
                or next; # ok

            $writer->write_seq( $amplicon->bioseq );
        }
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
