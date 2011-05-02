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

    my @amplicon_set_names = $self->build->amplicon_set_names;
    Carp::confess('No amplicon set names for '.$self->build->description) if not @amplicon_set_names; # bad

    my %assembler_params = $self->processing_profile->assembler_params_as_hash;
    my ($reads_attempted, $reads_processed) = (qw/ 0 0 /);
    for my $name ( @amplicon_set_names ) {
        my $amplicon_set = $self->build->amplicon_set_for_name($name);
        next if not $amplicon_set;

        my $writer = $self->build->fasta_and_qual_writer_for_type_and_set_name('processed', $amplicon_set->name)
            or return;
    
        while ( my $amplicon = $amplicon_set->next_amplicon ) {
            $reads_attempted += @{$amplicon->{reads}};
            my $fasta_file = $self->build->reads_fasta_file_for_amplicon($amplicon);
            next unless -s $fasta_file; # ok

            my $phrap = Genome::Model::Tools::PhredPhrap::Fasta->create(
                fasta_file => $fasta_file,
                %assembler_params,
            );

            unless ( $phrap ) { # bad
                $self->error_message(
                    "Can't create phred phrap command for build's (".$self->build->id.") amplicon (".$amplicon->{name}.")"
                );
                return;
            }

            $phrap->dump_status_messages(1);
            $phrap->execute;

            $self->build->load_seq_for_amplicon($amplicon)
                or next; # ok

            $writer->write([$amplicon->{seq}]);
            $reads_processed += @{$amplicon->{reads_processed}};
        }
    }

    $self->build->reads_attempted($reads_attempted);
    $self->build->reads_processed($reads_processed);
    $self->build->reads_processed_success( $reads_processed > 0 ?  sprintf('%.2f', $reads_processed / $reads_attempted) : 0 );

    return 1;
}

1;

