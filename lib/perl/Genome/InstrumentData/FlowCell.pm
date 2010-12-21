package Genome::InstrumentData::FlowCell;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::FlowCell {
    type_name  => 'system flowcell',
        table_name => 'GSC.flow_cell_illumina',
            id_by      => [ flow_cell_id => { is => 'VARCHAR2', len => 15 }, ],
            has        => [
                machine_name      => { is => 'VARCHAR2', len => 64 },
                run_name          => { is => 'VARCHAR2', len => 64 },
                run_type          => { is => 'VARCHAR2', len => 25 },
                creation_event_id => => { is => 'NUMBER', len => 15 },
                team_name         => { is => 'VARCHAR2', len => 64 },
                group_name        => { is => 'VARCHAR2', len => 64 },
                production_started => {
                    is => 'Text',
                    len => 255,
                    calculate => q(
                         my @runs = $self->solexa_runs();
                         my $pse_id = $runs[0]->creation_event_id() || return;
                         my $creation_event = GSC::PSE->get(pse_id => $pse_id);
                         return $creation_event->date_scheduled();
                    ),
                },
                lanes => {
                    is  => 'Genome::InstrumentData::Solexa',
                    reverse_as  => 'flow_cell',
                    is_many => 1,
                },
                lane_info => {
                    is => 'Array',
                    calculate => q(
                       return $self->lane_info();
                    ),
                },
                instrument_data_ids => {
                    is => 'Array',
                    calculate => q(
                        return map { $_->{id} } $self->lane_info;
                    ),
                },
                illimina_index => {
                    is => 'Array',
                    calculate => q(
                        return $self->illumina_index();
                    ),
                }

            ],
                schema_name => 'GMSchema',
                    data_source => 'Genome::DataSource::GMSchema',
                };

#            where   => [ flow_cell_id => '' ],
#            to => 'value',

sub solexa_runs {

    # oltp solexa_run
    my ($self) = @_;

    my @runs = GSC::Equipment::Solexa::Run->get( flow_cell_id => $self->flow_cell_id );

    return @runs;
}

sub lane_info {
    my ($self) = @_;
    my @lanes_info;

    for my $lane ($self->lanes) {
        my %lane_info;

        my @fs_ids = GSC::Sequence::ItemFile->get( seq_id => $lane->seq_id );
        my @files = GSC::FileStorage->get( file_storage_id => \@fs_ids );

        $lane_info{lane} = $lane->lane;
        $lane_info{subset_name} = $lane->subset_name;
        $lane_info{id} = $lane->id;
        $lane_info{gerald_directory} = $lane->gerald_directory;

        my @lane_reports;

        for my $file (@files) {
            next unless $file->file_name =~ m/\.report\.xml$/;
            push (@lane_reports, $file->file_name);
        }

        $lane_info{lane_reports} = [ @lane_reports ];

        push(@lanes_info, \%lane_info);




    }

    return @lanes_info
}

sub illumina_index {
    my ($self) = @_;
    my @idx = Genome::InstrumentData::Solexa->get(flow_cell_id => $self->flow_cell_id);
    my $index_sequences = {};
    my $indexes = {};

    # if index_sequence of any lane is undef, then this is not an indexed flow cell
    if ($idx[0]->index_sequence) {

        for my $i (@idx) {

            my $index_sequence = $i->index_sequence();
            $index_sequences->{$index_sequence} = 1;

            $indexes->{$i->lane()}->{$index_sequence} = $i;
        }

        # index_sequences is all the sequences that exist in any lane
        # indexes may contain a lane that is missing an index_sequence
        return ($index_sequences, $indexes);
    } else {
        return undef;
    }

}
1;
